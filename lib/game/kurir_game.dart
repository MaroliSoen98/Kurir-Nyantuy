import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'components/player.dart';
import 'components/obstacle.dart';
import 'components/coin.dart';
import 'components/hud.dart';
import 'components/magnet.dart';

class KurirGame extends FlameGame with PanDetector, KeyboardEvents {
  late Player player;

  // Kecepatan game akan terus bertambah seiring waktu
  double gameSpeed = 1000.0; // Dipercepat sedikit untuk skala ruang 3D
  final Random _random = Random();

  // Flag Debugging: Set true untuk force malam, set false untuk kembali normal
  bool debugForceNight = false;

  // Scoring & Progression Offline Sementara
  double distanceTravelled = 0.0;
  int currentCoins = 0;
  int totalCoinsPlayer = 0;
  double bestDistance = 0.0;
  int nextMilestone = 100;
  bool isGameOver = false;
  bool isPaused = false; // Status apakah game sedang di-pause
  int playerLives = 3;
  int _skipSpawnTicks = 0; // Jeda antar pola panjang

  late SharedPreferences prefs;

  // Properti Kamera Perspektif Pseudo-3D
  double get horizonY => size.y * 0.35;
  double get focusDepth => 300.0; // Seberapa cepat objek mengecil
  double get cameraHeight => size.y * 0.5; // Ketinggian kamera dari aspal

  double getScale(double z) {
    if (z <= -focusDepth) return 0.01; // Mencegah glitch divide-by-zero
    return focusDepth / (focusDepth + z);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Inisialisasi SharedPreferences dan muat data yang tersimpan
    prefs = await SharedPreferences.getInstance();
    bestDistance = prefs.getDouble('bestDistance') ?? 0.0;
    totalCoinsPlayer = prefs.getInt('totalCoinsPlayer') ?? 0;

    // Pra-muat aset gambar agar tidak lag saat pertama kali dirender
    try {
      await images.loadAll([
        'motor.png',
        'motor_left.png',
        'motor_right.png',
        'motor_nunduk.png', // <-- TAMBAHKAN INI
        'koin.png',
        'kucing.png',
        'ibumotor.png',
        'portal.png',
        'galian_depan.png',
        'galian_tengah.png',
        'galian_belakang.png',
        'cloud.png',
        'magnet.png', // <-- Tambahkan aset magnet ke dalam daftar load
      ]);
    } catch (e) {
      debugPrint("Beberapa gambar belum ada, dilewati untuk preload.");
    }

    // Background Jalanan Perspektif Pseudo-3D
    add(RoadBackground());

    // Inisialisasi pemain
    player = Player();
    add(player);

    // Tambahkan Layar Informasi Gameplay (HUD)
    add(HudComponent());

    // Sistem Pencahayaan & Kegelapan Malam
    add(LightingSystem());

    // Spawner rintangan setiap 1.0 detik agar jalanan tidak pernah kosong
    add(TimerComponent(period: 1.0, repeat: true, onTick: _spawnObstacle));

    // Menambahkan Indikator FPS di pojok kanan atas untuk memantau Lag
    add(
      FpsTextComponent(
        position: Vector2(size.x - 20, 50),
        anchor: Anchor.topRight,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ),
    );

    // Hentikan sementara mesin agar game tidak berjalan otomatis sebelum tombol Play ditekan
    pauseEngine();
  }

  // Fungsi untuk memulai game dan musik
  Future<void> startGame() async {
    // Hapus menu utama dan tampilkan layar loading
    overlays.remove('MainMenu');
    overlays.add('Loading');

    // Beri jeda sesaat agar UI sempat me-render layar loading
    // Diberi jeda 1.5 detik untuk memberikan kesan loading yang lebih solid
    await Future.delayed(const Duration(milliseconds: 1500));

    resumeEngine(); // Lanjutkan game

    overlays.remove('Loading'); // Sembunyikan kembali layar loading
    overlays.add('PauseButton'); // Tampilkan tombol Pause di ujung layar
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    // Update skor meter berdasarkan kecepatan gerak (Disesuaikan rasio realita)
    distanceTravelled += (gameSpeed * dt) / 100.0;
    gameSpeed += 5.0 * dt; // Tantangan meningkat berkala sedikit lebih cepat

    // Cek Perayaan Milestone / Jarak Tertentu
    if (distanceTravelled >= nextMilestone) {
      currentCoins += 15; // Hadiah Bonus
      gameSpeed += 40.0; // Speed Boost Dadakan biar greget

      // Skala Milestone Eksponensial (100, 250, 500, 1000, dst..)
      if (nextMilestone < 1000) {
        nextMilestone += (nextMilestone == 100 ? 150 : 250);
      } else {
        nextMilestone += 1000;
      }
    }
  }

  // Helper fungsi untuk membuat pola koin melengkung menyerupai kurva lompatan
  void _spawnCoinArc(
    double laneX,
    double startZ,
    double endZ,
    int count, {
    bool addMagnetAtPeak = false,
  }) {
    for (int i = 0; i < count; i++) {
      double t = (count > 1) ? (i / (count - 1)) : 0.5;
      // Puncak arc disesuaikan agar item melayang jelas dengan sudut elevasi di atas galian
      double arcY = -140.0 * sin(t * pi);
      double currentZ = startZ + (endZ - startZ) * t;

      if (addMagnetAtPeak && i == count ~/ 2) {
        // Taruh Magnet tepat di puncak (peak) lompatan
        add(
          Magnet(worldX: laneX, worldZ: currentZ, baseSize: Vector2(40, 40))
            ..worldY = arcY - 30.0,
        );
      } else {
        add(
          Coin(worldX: laneX, worldZ: currentZ, baseSize: Vector2(40, 40))
            ..worldY = arcY - 30.0,
        );
      }
    }
  }

  // Helper fungsi untuk membuat barisan koin lurus yang rapi
  void _spawnCoinLine(
    double laneX,
    double startZ,
    int count, {
    double spacing = 100.0,
    bool addMagnet = false,
  }) {
    int magnetIndex = addMagnet
        ? (count ~/ 2)
        : -1; // Magnet selalu di tengah barisan jika ada
    for (int i = 0; i < count; i++) {
      double currentZ = startZ + (i * spacing);
      if (i == magnetIndex) {
        add(Magnet(worldX: laneX, worldZ: currentZ, baseSize: Vector2(40, 40)));
      } else {
        add(Coin(worldX: laneX, worldZ: currentZ, baseSize: Vector2(40, 40)));
      }
    }
  }

  void _spawnObstacle() {
    if (isGameOver) return;

    // Peluang 10% untuk memunculkan Magnet secara rapi di dalam pola (Bukan asal taruh)
    bool spawnMagnet = _random.nextDouble() < 0.10;

    // Beri jeda kosong jika pola sebelumnya sangat panjang agar tidak tumpang tindih
    if (_skipSpawnTicks > 0) {
      _skipSpawnTicks--;

      // Variasi "Filler": 50% Barisan Koin Panjang, 50% Blok Koin ala Subway Surfer
      if (_random.nextBool()) {
        final double fillerLane = (_random.nextInt(3) - 1).toDouble();
        _spawnCoinLine(
          fillerLane * 180.0,
          2200.0,
          8,
          spacing: 90.0,
          addMagnet: spawnMagnet,
        );
      } else {
        // Blok Koin Lebar 3 Lajur x 3 Baris
        for (double l in [-1.0, 0.0, 1.0]) {
          _spawnCoinLine(
            l * 180.0,
            2200.0,
            3,
            spacing: 120.0,
            addMagnet: (l == 0.0) ? spawnMagnet : false,
          );
        }
      }
      return;
    }

    final double laneSpacing = 180.0;
    final int pattern = _random.nextInt(7); // Acak 1 dari 7 Skenario Pola
    final double startZ =
        2200.0; // Dimulai sedikit lebih jauh agar pola panjang tertata rapi

    switch (pattern) {
      case 0: // POLA 0: Ular Koin (Melengkung) & Rintangan Kejutan
        final curveLanes = [1.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0];
        final startSide = _random.nextBool() ? 1.0 : -1.0;
        for (int i = 0; i < curveLanes.length; i++) {
          add(
            Coin(
              worldX: curveLanes[i] * startSide * laneSpacing,
              worldZ: startZ + (i * 150.0),
              baseSize: Vector2(40, 40),
            ),
          );
        }
        // Tambahkan galian pendek di ujung
        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ + 1200.0,
            baseSize: Vector2(140, 40),
            isSmall: true,
            depthZ: 250.0,
          ),
        );
        // Center arc disesuaikan TEPAT di atas titik tengah galian (Center galian = 1200 + 125 = 1325)
        // Arc dari 1050 sampai 1600 = Center persis di 1325. Sangat rapi!
        _spawnCoinArc(
          0.0,
          startZ + 1050.0,
          startZ + 1600.0,
          5,
          addMagnetAtPeak: spawnMagnet,
        );
        _skipSpawnTicks = 1;
        break;

      case 1: // POLA 1: Portal & Reward (Geser Nunduk)
        add(
          Obstacle(
            worldX: 0,
            worldZ: startZ,
            baseSize: Vector2(600, 80),
            isFloating: true,
          ),
        );
        final double safeLane = (_random.nextInt(3) - 1).toDouble();

        // Koin baris rapi melewati bawah portal
        _spawnCoinLine(
          safeLane * laneSpacing,
          startZ + 200.0,
          5,
          spacing: 120.0,
          addMagnet: spawnMagnet,
        );
        break;

      case 2: // POLA 2: Emak-Emak Zig-Zag + Koin Penuntun Celah Aman
        add(
          Obstacle(
            worldX: -laneSpacing,
            worldZ: startZ,
            baseSize: Vector2(140, 120),
            canDrift: true,
          ),
        );
        // Barisan 3 koin penuntun untuk celah aman pertama
        _spawnCoinLine(laneSpacing, startZ - 100.0, 3, spacing: 100.0);

        add(
          Obstacle(
            worldX: laneSpacing,
            worldZ: startZ + 500.0,
            baseSize: Vector2(140, 120),
            canDrift: true,
          ),
        );
        // Barisan 3 koin penuntun untuk celah aman kedua
        _spawnCoinLine(
          -laneSpacing,
          startZ + 400.0,
          3,
          spacing: 100.0,
          addMagnet: spawnMagnet,
        ); // Selipkan magnet di jalur aman ini

        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ + 1000.0,
            baseSize: Vector2(140, 120),
            canDrift: true,
          ),
        );
        // Barisan 3 koin penuntun untuk celah aman ketiga
        _spawnCoinLine(laneSpacing, startZ + 900.0, 3, spacing: 100.0);

        _skipSpawnTicks = 1;
        break;

      case 3: // POLA 3: The Squeeze (Terowongan Galian Panjang + Koin + Jebakan)
        add(
          Obstacle(
            worldX: -laneSpacing,
            worldZ: startZ,
            baseSize: Vector2(140, 40),
            isSmall: true,
            depthZ: 1200.0,
          ),
        );
        add(
          Obstacle(
            worldX: laneSpacing,
            worldZ: startZ,
            baseSize: Vector2(140, 40),
            isSmall: true,
            depthZ: 1200.0,
          ),
        );

        // Koin aman berada persis lurus di dalam terowongan
        _spawnCoinLine(
          0.0,
          startZ + 150.0,
          5,
          spacing: 180.0,
          addMagnet: spawnMagnet,
        );

        // Jebakan emak-emak statis di ujung koin! Pemain harus sigap menghindar
        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ + 1400.0,
            baseSize: Vector2(140, 120),
            canDrift: false,
          ),
        );
        _skipSpawnTicks = 2;
        break;

      case 4: // POLA 4: Leap of Faith (Koin Melayang di atas Galian!)
        final double emptyLane = (_random.nextInt(3) - 1).toDouble();
        bool magnetPlaced = false;
        for (double l in [-1.0, 0.0, 1.0]) {
          if (l == emptyLane) {
            add(
              Obstacle(
                worldX: l * laneSpacing,
                worldZ: startZ,
                baseSize: Vector2(140, 120),
                canDrift: false,
              ),
            );
          } else {
            add(
              Obstacle(
                worldX: l * laneSpacing,
                worldZ: startZ,
                baseSize: Vector2(140, 40),
                isSmall: true,
                depthZ: 250.0,
              ),
            );
            // Arc ditarik presisi membungkus kedalaman galian (Center galian startZ + 125)
            // Arc dari startZ - 150 sampai startZ + 400 = Center persis di startZ + 125.
            _spawnCoinArc(
              l * laneSpacing,
              startZ - 150.0,
              startZ + 400.0,
              5,
              addMagnetAtPeak: (spawnMagnet && !magnetPlaced),
            );
            magnetPlaced = true; // Cukup 1 magnet per pola
          }
        }
        break;

      case 5: // POLA 5: The Wall (2 Lajur diblokir tembok, 1 lajur aman ditandai Koin)
        final double safeLane5 = (_random.nextInt(3) - 1).toDouble();
        for (double l in [-1.0, 0.0, 1.0]) {
          if (l == safeLane5) {
            _spawnCoinLine(
              l * laneSpacing,
              startZ,
              4,
              spacing: 120.0,
              addMagnet: spawnMagnet,
            );
          } else {
            add(
              Obstacle(
                worldX: l * laneSpacing,
                worldZ: startZ,
                baseSize: Vector2(140, 120),
                canDrift: false,
              ),
            );
          }
        }
        break;

      case 6: // POLA 6: Reflex Gauntlet (Galian -> Koin -> Portal -> Ibu-ibu)
        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ,
            baseSize: Vector2(140, 40),
            isSmall: true,
            depthZ: 250.0,
          ),
        );
        // Center arc disesuaikan agar simetris mengangkangi galian
        _spawnCoinArc(
          0.0,
          startZ - 150.0,
          startZ + 400.0,
          5,
          addMagnetAtPeak: spawnMagnet,
        );

        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ + 700.0,
            baseSize: Vector2(600, 80),
            isFloating: true,
          ),
        );

        final double sideLane6 = _random.nextBool() ? -1.0 : 1.0;
        // Ubah koin tunggal menjadi barisan 3 koin penuntun di pinggir
        _spawnCoinLine(
          -sideLane6 * laneSpacing,
          startZ + 900.0,
          3,
          spacing: 100.0,
        );
        add(
          Obstacle(
            worldX: sideLane6 * laneSpacing,
            worldZ: startZ + 1200.0,
            baseSize: Vector2(140, 120),
            canDrift: true,
          ),
        );

        _skipSpawnTicks = 1;
        break;
    }
  }

  void playerHit() {
    if (isGameOver) return;

    playerLives--;
    player.triggerInvincibility();

    if (playerLives <= 0) {
      isGameOver = true;
      pauseEngine(); // Hentikan game loop (game freeze)
      overlays.remove('PauseButton'); // Sembunyikan tombol pause

      // Update rekaman skor tinggi
      if (distanceTravelled > bestDistance) {
        bestDistance = distanceTravelled;
        prefs.setDouble('bestDistance', bestDistance); // Simpan ke storage
      }

      totalCoinsPlayer += currentCoins;
      prefs.setInt('totalCoinsPlayer', totalCoinsPlayer); // Simpan ke storage

      overlays.add('GameOver'); // Munculkan Widget Layar Penuh
    }
  }

  void resetGame() {
    isGameOver = false;
    isPaused = false;
    playerLives = 3;
    distanceTravelled = 0.0;
    currentCoins = 0;
    gameSpeed = 1000.0;
    nextMilestone = 100;
    player.hasShield = false;
    player.isMagnetActive = false; // Matikan efek magnet jika ada

    // Bersihkan rintangan & koin dari sisa permainan sebelumnya
    // Menggunakan toList() memastikan iterasi aman sebelum penghapusan.
    removeAll(children.whereType<Obstacle>().toList());
    removeAll(children.whereType<Coin>().toList());
    removeAll(children.whereType<Magnet>().toList());
  }

  // Fungsi untuk menghentikan sementara (Pause)
  void pauseGame() {
    if (isGameOver || isPaused) return;
    isPaused = true;
    pauseEngine();
    overlays.remove('PauseButton');
    overlays.add('PauseMenu');
  }

  // Fungsi untuk melanjutkan game (Resume)
  void resumeGame() {
    if (!isPaused) return;
    isPaused = false;
    overlays.remove('PauseMenu');
    resumeEngine();
    overlays.add('PauseButton');
  }

  // Mendeteksi gesture swipe dari pemain
  @override
  void onPanEnd(DragEndInfo info) {
    final velocity = info.velocity;
    final dx = velocity.x;
    final dy = velocity.y;

    if (isPaused) return; // Nonaktifkan gerak jika sedang di-pause

    // Tentukan apakah swipe lebih condong ke horizontal atau vertikal
    if (dx.abs() > dy.abs()) {
      if (dx > 0) {
        player.moveRight();
      } else {
        player.moveLeft();
      }
    } else {
      if (dy < 0) {
        player.jump();
      } else {
        player.slide();
      }
    }
  }

  // Mendeteksi input dari Keyboard (WASD & Arrow Keys)
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isKeyDown = event is KeyDownEvent;

    if (isKeyDown) {
      // Tombol Pause Cepat (Escape / P)
      if (keysPressed.contains(LogicalKeyboardKey.escape) ||
          keysPressed.contains(LogicalKeyboardKey.keyP)) {
        if (isPaused) {
          resumeGame();
        } else {
          pauseGame();
        }
        return KeyEventResult.handled;
      }

      if (isPaused)
        return super.onKeyEvent(
          event,
          keysPressed,
        ); // Abaikan input jika game pause

      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
          keysPressed.contains(LogicalKeyboardKey.keyA)) {
        player.moveLeft();
        return KeyEventResult.handled;
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
          keysPressed.contains(LogicalKeyboardKey.keyD)) {
        player.moveRight();
        return KeyEventResult.handled;
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
          keysPressed.contains(LogicalKeyboardKey.keyW)) {
        player.jump();
        return KeyEventResult.handled;
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
          keysPressed.contains(LogicalKeyboardKey.keyS)) {
        player.slide();
        return KeyEventResult.handled;
      }
    }

    return super.onKeyEvent(event, keysPressed);
  }
}

// --- Background Parallax Jalanan Pseudo 3D ---
class RoadBackground extends Component with HasGameRef<KurirGame> {
  RoadBackground() : super(priority: -1); // Selalu render paling belakang

  // Warna patokan untuk transisi waktu
  final Color _dayColor = const Color(0xFF87CEEB); // Siang (Biru Terang)
  final Color _eveningColor = const Color(0xFFFF8C00); // Sore (Jingga/Orange)
  final Color _nightColor = const Color(0xFF0A0F24); // Malam (Biru Gelap/Hitam)

  // Simpan warna (Paint) di luar render agar tidak membebani memori setiap frame (Mencegah LAG!)
  final Paint skyPaint = Paint()..color = const Color(0xFF87CEEB);
  final Paint grassPaint = Paint()..color = const Color(0xFF4CAF50);
  final Paint shoulderPaint = Paint()..color = const Color(0xFF8D6E63);
  final Paint roadPaint = Paint()..color = const Color(0xFF444444);
  final Paint linePaint = Paint()..color = Colors.white;
  final Paint starPaint = Paint()..color = Colors.white;

  // Properti Bintang (Parallax)
  final Random _rand = Random();
  final List<double> _starX = [];
  final List<double> _starY = [];
  final List<double> _starSize = [];
  bool _starsInitialized = false;

  // Mendaftar objek Path satu kali saja untuk didaur ulang (SANGAT MENGHEMAT MEMORI & MENCEGAH LAG)
  final Path _renderPath = Path();

  // Properti Awan
  Sprite? _cloudSprite;
  double _cloudOffset = 0.0;
  double _cloudDirection = -1.0; // Penentu arah gerak awan (Ping-Pong)
  final Paint _cloudPaint = Paint()..filterQuality = FilterQuality.none;

  // Objek statis untuk mencegah GC Lag
  static final Vector2 _cachedCloudPos = Vector2.zero();
  static final Vector2 _cachedCloudSize = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _cloudSprite = Sprite(gameRef.images.fromCache('cloud.png'));
    } catch (e) {
      debugPrint("Gambar awan tidak ditemukan.");
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Inisialisasi posisi bintang pertama kali (Mencegah lag karena dibuat hanya sekali)
    if (!_starsInitialized) {
      for (int i = 0; i < 60; i++) {
        _starX.add(_rand.nextDouble() * gameRef.size.x);
        _starY.add(_rand.nextDouble() * gameRef.horizonY);
        _starSize.add(_rand.nextDouble() * 1.5 + 0.5); // Ukuran acak 0.5 - 2.0
      }
      _starsInitialized = true;
    }

    // Gunakan Modulo (%) agar siklus Siang-Malam berputar terus setiap 3000 meter!
    final double cycleDistance = gameRef.debugForceNight
        ? 2000.0
        : (gameRef.distanceTravelled % 3000.0);

    // Gerakkan bintang terus menerus jika sedang berada di fase Sore/Malam
    if (cycleDistance > 1000.0 && cycleDistance <= 3000.0) {
      for (int i = 0; i < _starY.length; i++) {
        _starY[i] +=
            (gameRef.gameSpeed * 0.015) * dt; // Kecepatan parallax lambat
        if (_starY[i] > gameRef.horizonY) {
          _starY[i] = 0; // Kembalikan ke atas saat melewati horizon
          _starX[i] = _rand.nextDouble() * gameRef.size.x;
        }
      }
    }

    // Kalkulasi Transisi Warna Langit yang looping secara halus
    if (cycleDistance <= 1000.0) {
      // 0 - 1000m: Transisi Siang ke Sore
      double t = cycleDistance / 1000.0;
      skyPaint.color = Color.lerp(_dayColor, _eveningColor, t) ?? _dayColor;
    } else if (cycleDistance <= 2000.0) {
      // 1000m - 2000m: Transisi Sore ke Malam
      double t = (cycleDistance - 1000.0) / 1000.0;
      skyPaint.color =
          Color.lerp(_eveningColor, _nightColor, t) ?? _eveningColor;
    } else {
      // 2000m - 3000m: Transisi Malam kembali ke Siang
      double t = (cycleDistance - 2000.0) / 1000.0;
      skyPaint.color = Color.lerp(_nightColor, _dayColor, t) ?? _nightColor;
    }

    // Pergerakan Awan (Parallax)
    if (_cloudSprite != null) {
      _cloudOffset += 10.0 * dt * _cloudDirection; // Awan gerak kiri/kanan
      double minOffset =
          -(gameRef.size.x * 0.5); // Batas maksimal geser ke kiri

      if (_cloudOffset <= minOffset) {
        _cloudOffset = minOffset;
        _cloudDirection = 1.0; // Putar balik ke kanan
      } else if (_cloudOffset >= 0) {
        _cloudOffset = 0;
        _cloudDirection = -1.0; // Putar balik ke kiri
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Langit
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.horizonY),
      skyPaint,
    );

    // --- Menggambar Awan Berjalan (Parallax) ---
    if (_cloudSprite != null) {
      // PERBAIKAN ANTI-LAG:
      // 1. Hapus ColorFilter & BlendMode.multiply yang memaksa GPU HP bekerja keras tiap frame.
      // 2. Gunakan Alpha (opacity) agar awan membaur natural dengan warna langit di belakangnya!
      _cloudPaint.color = const Color(0x77FFFFFF); // Putih transparan (~45%)

      final cloudWidth =
          gameRef.size.x * 1.5; // Diperlebar 1.5x layar untuk ruang ping-pong
      final cloudHeight = gameRef.horizonY * 0.8;

      _cachedCloudPos.setValues(_cloudOffset, 0);
      _cachedCloudSize.setValues(cloudWidth, cloudHeight);

      // Hanya gambar 1 awan saja untuk meringankan beban render hingga 50%!
      _cloudSprite!.render(
        canvas,
        position: _cachedCloudPos,
        size: _cachedCloudSize,
        overridePaint: _cloudPaint,
      );
    }

    // --- Menggambar Bintang di Malam Hari ---
    final double cycleDistance = gameRef.debugForceNight
        ? 2000.0
        : (gameRef.distanceTravelled % 3000.0);
    if (cycleDistance > 1000.0 && cycleDistance <= 3000.0) {
      for (int i = 0; i < _starX.length; i++) {
        canvas.drawCircle(
          Offset(_starX[i], _starY[i]),
          _starSize[i],
          starPaint,
        );
      }
    }

    // Tanah Pinggiran (Rumput)
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        gameRef.horizonY,
        gameRef.size.x,
        gameRef.size.y - gameRef.horizonY,
      ),
      grassPaint, // Menggunakan warna yang sudah disimpan
    );

    final center = gameRef.size.x / 2;
    final laneSpacing = 180.0;
    final scaleBottom = gameRef.getScale(-200);

    final topY = gameRef.horizonY;
    final bottomY = gameRef.horizonY + (gameRef.cameraHeight * scaleBottom);

    // Menggambar Bahu Jalan (Tanah/Kerikil khas pinggir jalan Indonesia)
    _renderPath.reset();
    _renderPath
      ..moveTo(center, topY)
      ..lineTo(center - (1.8 * laneSpacing * scaleBottom), bottomY)
      ..lineTo(center + (1.8 * laneSpacing * scaleBottom), bottomY)
      ..close();
    canvas.drawPath(_renderPath, shoulderPaint);

    // Menggambar jalan aspal utama (Poligon menyempit ke horizon)
    _renderPath.reset();
    _renderPath
      ..moveTo(center, topY)
      ..lineTo(center - (1.5 * laneSpacing * scaleBottom), bottomY)
      ..lineTo(center + (1.5 * laneSpacing * scaleBottom), bottomY)
      ..close();
    canvas.drawPath(_renderPath, roadPaint); // Aspal lebih gelap

    // Offset untuk animasi marka jalan putus-putus
    final dashLength = 120.0;
    final dashGap = 120.0;
    final cycle = dashLength + dashGap;
    final moveOffset = (gameRef.distanceTravelled * 100) % cycle;

    // Menggambar 4 garis marka jalan (Tepi solid, Tengah putus-putus)
    for (int i = -1; i <= 2; i++) {
      final laneOffset = (i - 0.5) * laneSpacing;

      if (i == -1 || i == 2) {
        // Garis Tepi (Solid)
        final scale1 = gameRef.getScale(-200);
        final scale2 = gameRef.getScale(
          20000,
        ); // Diperpanjang sampai ujung horizon

        final screenY1 = topY + (gameRef.cameraHeight * scale1);
        final screenY2 = topY + (gameRef.cameraHeight * scale2);

        final lineWidth1 = 4.0 * scale1; // Tepi sedikit lebih tipis
        final lineWidth2 = 4.0 * scale2;

        final screenX1 = center + (laneOffset * scale1);
        final screenX2 = center + (laneOffset * scale2);

        _renderPath.reset();
        _renderPath
          ..moveTo(screenX1 - lineWidth1, screenY1)
          ..lineTo(screenX1 + lineWidth1, screenY1)
          ..lineTo(screenX2 + lineWidth2, screenY2)
          ..lineTo(screenX2 - lineWidth2, screenY2)
          ..close();
        canvas.drawPath(_renderPath, linePaint);
      } else {
        // Garis Tengah (Putus-putus)
        _renderPath.reset(); // RESET SEKALI DI SINI
        // Batasi render marka hingga 4000 saja. Di atas 4000 ukurannya lebih kecil
        // dari 1 pixel, menggambarnya sampai 20000 hanya membakar daya GPU dan bikin lag.
        for (double z = -200 - moveOffset; z < 4000; z += cycle) {
          final z1 = z;
          final z2 = z + dashLength;

          if (z2 < -200) continue;
          if (z1 > 20000) break;

          // Batasi titik Z agar tidak melebihi horizon / layar bawah
          final actualZ1 = max(-200.0, z1);
          final actualZ2 = min(20000.0, z2);

          final scale1 = gameRef.getScale(actualZ1);
          final scale2 = gameRef.getScale(actualZ2);

          final screenY1 = topY + (gameRef.cameraHeight * scale1);
          final screenY2 = topY + (gameRef.cameraHeight * scale2);

          final lineWidth1 = 6.0 * scale1; // Tengah lebih tebal dan jelas
          final lineWidth2 = 6.0 * scale2;

          final screenX1 = center + (laneOffset * scale1);
          final screenX2 = center + (laneOffset * scale2);

          _renderPath
            ..moveTo(screenX1 - lineWidth1, screenY1)
            ..lineTo(screenX1 + lineWidth1, screenY1)
            ..lineTo(screenX2 + lineWidth2, screenY2)
            ..lineTo(screenX2 - lineWidth2, screenY2)
            ..close();
        }
        // GAMBAR SEMUA GARIS SEKALIGUS DALAM 1 PANGGILAN GPU! (HEMAT RESOURCE)
        canvas.drawPath(_renderPath, linePaint);
      }
    }
  }
}

// --- Sistem Pencahayaan Malam Hari (Headlight Masking) ---
class LightingSystem extends Component with HasGameRef<KurirGame> {
  LightingSystem() : super(priority: 50);

  final Paint _darknessPaint = Paint()..color = Colors.black;
  final Paint _holePunchPaint = Paint()
    ..blendMode = BlendMode.dstOut; // Blur Dihapus (Sangat membebani FPS!)
  final Paint _beamPaint = Paint(); // Blur Dihapus
  final Paint _cachedLayerPaint = Paint(); // Di-cache agar tidak nyampah memory
  final Path _lightConePath = Path();

  @override
  void render(Canvas canvas) {
    final double cycleDistance = gameRef.debugForceNight
        ? 2000.0
        : (gameRef.distanceTravelled % 3000.0);
    double darkness = 0.0;

    if (cycleDistance > 800.0 && cycleDistance <= 1500.0) {
      darkness = ((cycleDistance - 800.0) / 700.0) * 0.95;
    } else if (cycleDistance > 1500.0 && cycleDistance <= 2500.0) {
      darkness = 0.95;
    } else if (cycleDistance > 2500.0) {
      darkness = (1.0 - ((cycleDistance - 2500.0) / 500.0)) * 0.95;
    }

    if (darkness > 0.0) {
      final player = gameRef.player;

      final jumpOffset = (player.worldY / -150.0).clamp(0.0, 1.0);

      // --- Parameter Sorot Lampu Horizon Chase Style ---
      const double beamLength =
          5500.0; // Diperpanjang jauh agar menembus horizon
      final adjustedBeamLength = beamLength + (jumpOffset * 400.0);

      const double nearBeamWidth =
          15.0; // Dipersempit (dipendekin lebarnya) agar mengerucut mirip segitiga tumpul
      const double farBeamWidth =
          1300.0; // Diperlebar sedikit lagi agar jangkauan pandangan ke samping lebih luas

      final zNear = player.worldZ + 10;
      final zFar = player.worldZ + adjustedBeamLength;

      final scaleNear = gameRef.getScale(zNear);
      final scaleFar = gameRef.getScale(zFar);

      // Angkat titik asal sorotan (yNear) sejauh ~50 pixel ke atas.
      // Angka -50 membuat lampunya lebih merunduk dan sangat nempel ke aspal.
      // Ikut sertakan posisi Y pemain agar lampu ikut naik/turun presisi saat lompat atau nunduk!
      final yNear =
          gameRef.horizonY +
          ((gameRef.cameraHeight + player.worldY + player.slideYOffset - 50.0) *
              scaleNear);

      final yFar = gameRef.horizonY + (gameRef.cameraHeight * scaleFar);

      final xNearLeft =
          (gameRef.size.x / 2) +
          ((player.worldX - nearBeamWidth / 2) * scaleNear);
      final xNearRight =
          (gameRef.size.x / 2) +
          ((player.worldX + nearBeamWidth / 2) * scaleNear);

      final xFarLeft =
          (gameRef.size.x / 2) +
          ((player.worldX - farBeamWidth / 2) * scaleFar);
      final xFarRight =
          (gameRef.size.x / 2) +
          ((player.worldX + farBeamWidth / 2) * scaleFar);

      // Titik tengah ujung sorotan di horizon (Sebagai titik lengkung kurva halus)
      final xFarCenter = (gameRef.size.x / 2) + (player.worldX * scaleFar);

      _lightConePath.reset();
      _lightConePath.moveTo(xNearLeft, yNear);
      _lightConePath.lineTo(xNearRight, yNear);
      _lightConePath.lineTo(
        xFarRight,
        yFar,
      ); // Menyebar langsung ke ujung Kanan (Membentuk V)

      // --- BENTUK NATURAL TANPA BLUR (100% No FPS Drop) ---
      // Lengkungan sangat halus di ujung agar transisinya tidak terpotong garis lurus kaku
      _lightConePath.quadraticBezierTo(xFarCenter, yFar - 10.0, xFarLeft, yFar);

      _lightConePath.close();

      // LinearGradient untuk membuat lubang cahaya makin samar menyatu dengan jalan
      _holePunchPaint.shader = ui.Gradient.linear(
        Offset(0, yNear), // Titik asal (Motor)
        Offset(0, yFar), // Ujung cahaya (Horizon)
        [
          Colors.black.withOpacity(1.0), // Lubang terang benderang di pangkal
          Colors.black.withOpacity(
            0.85,
          ), // Masih sangat jernih di pertengahan jalan
          Colors.black.withOpacity(0.0), // Cahaya menyatu dengan gelap di ujung
        ],
        [
          0.0,
          0.65,
          1.0,
        ], // Jarak pandang bersih dipertahankan hingga 65% jarak sorotan
      );

      // Gradien cahaya putih yang makin transparan di horizon
      // Opacity diturunkan drastis agar tidak terlihat seperti "kabut/susu" yang menghalangi pandangan
      _beamPaint.shader = ui.Gradient.linear(
        Offset(0, yNear),
        Offset(0, yFar),
        [
          Colors.white.withOpacity(
            0.25,
          ), // Cahaya tipis natural, jalanan terlihat aslinya
          Colors.white.withOpacity(0.10),
          Colors.white.withOpacity(0.0), // Pudar di ujung
        ],
        [0.0, 0.65, 1.0],
      );

      _darknessPaint.color = Colors.black.withOpacity(darkness);

      final roadRect = Rect.fromLTWH(
        0,
        gameRef.horizonY,
        gameRef.size.x,
        gameRef.size.y - gameRef.horizonY,
      );

      // Gunakan saveLayer agar bisa menghapus area gelap dengan gradasi yang halus
      canvas.saveLayer(roadRect, _cachedLayerPaint);
      canvas.drawRect(roadRect, _darknessPaint); // Render lapisan malam total
      canvas.drawPath(
        _lightConePath,
        _holePunchPaint,
      ); // Hapus pekatnya malam perlahan
      canvas.drawPath(
        _lightConePath,
        _beamPaint,
      ); // Tambahkan sorot lampu putih
      canvas.restore();
    }
  }
}
