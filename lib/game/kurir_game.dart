import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'components/player.dart';
import 'components/obstacle.dart';
import 'components/coin.dart';
import 'components/hud.dart';

class KurirGame extends FlameGame
    with PanDetector, KeyboardEvents, HasCollisionDetection {
  late Player player;

  // Kecepatan game akan terus bertambah seiring waktu
  double gameSpeed = 1000.0; // Dipercepat sedikit untuk skala ruang 3D
  final Random _random = Random();

  // Scoring & Progression Offline Sementara
  double distanceTravelled = 0.0;
  int currentCoins = 0;
  int totalCoinsPlayer = 0;
  double bestDistance = 0.0;
  int nextMilestone = 100;
  bool isGameOver = false;
  int playerLives = 3;

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
        'koin.png',
        'kucing.png',
        'ibumotor.png',
        'portal.png',
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

    // Spawner rintangan setiap 1.2 detik menggunakan TimerComponent
    add(TimerComponent(period: 1.2, repeat: true, onTick: _spawnObstacle));

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
  void startGame() {
    resumeEngine();
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

  void _spawnObstacle() {
    if (isGameOver) return;

    final lanes = [-1, 0, 1];
    final lane = lanes[_random.nextInt(3)];
    final laneSpacing = 180.0; // Jarak ruang di 3D dunia
    final worldX = lane * laneSpacing;

    // 35% kemungkinan jalur disi Koin, 65% Rintangan
    if (_random.nextDouble() < 0.35) {
      // Pola koin berbaris
      for (int i = 0; i < 4; i++) {
        add(
          Coin(
            worldX: worldX,
            worldZ: 2000.0 + (i * 120.0),
            baseSize: Vector2(40, 40),
          ),
        );
      }
    } else {
      double rand = _random.nextDouble();
      if (rand < 0.20) {
        // 20% Muncul Rintangan Portal Gang (Melayang & Panjang melintang di 3 lane)
        add(
          Obstacle(
            worldX: 0, // Posisi tengah (X=0)
            worldZ: 2000.0,
            baseSize: Vector2(
              600,
              80,
            ), // Menutupi penuh lebar jalan aspal (3 lajur x 180)
            isFloating: true,
          ),
        );
      } else {
        // Sisanya rintangan darat: 25% Kecil, 55% Besar
        bool isSmall = rand < 0.45;
        // Angkot/Mobil dibuat lebar menutupi lajur, lubang/kucing dibuat lebih mungil
        final obstacleSize = isSmall ? Vector2(50, 50) : Vector2(140, 120);

        add(
          Obstacle(
            worldX: worldX,
            worldZ: 2000.0,
            baseSize: obstacleSize,
            isSmall: isSmall,
          ),
        );
      }
    }
  }

  void playerHit() {
    if (isGameOver) return;

    playerLives--;
    player.triggerInvincibility();

    if (playerLives <= 0) {
      isGameOver = true;
      pauseEngine(); // Hentikan game loop (game freeze)

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
    playerLives = 3;
    distanceTravelled = 0.0;
    currentCoins = 0;
    gameSpeed = 1000.0;
    nextMilestone = 100;
    player.hasShield = false;

    // Bersihkan rintangan & koin dari sisa permainan sebelumnya
    children.whereType<Obstacle>().forEach((o) => o.removeFromParent());
    children.whereType<Coin>().forEach((c) => c.removeFromParent());
  }

  // Mendeteksi gesture swipe dari pemain
  @override
  void onPanEnd(DragEndInfo info) {
    final velocity = info.velocity;
    final dx = velocity.x;
    final dy = velocity.y;

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
    final double cycleDistance = gameRef.distanceTravelled % 3000.0;

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
  }

  @override
  void render(Canvas canvas) {
    // Langit
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.horizonY),
      skyPaint,
    );
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
        for (double z = -200 - moveOffset; z < 20000; z += cycle) {
          // Diperpanjang sampai horizon
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

          _renderPath.reset();
          _renderPath
            ..moveTo(screenX1 - lineWidth1, screenY1)
            ..lineTo(screenX1 + lineWidth1, screenY1)
            ..lineTo(screenX2 + lineWidth2, screenY2)
            ..lineTo(screenX2 - lineWidth2, screenY2)
            ..close();
          canvas.drawPath(_renderPath, linePaint);
        }
      }
    }
  }
}

// --- Sistem Pencahayaan Malam Hari (Headlight Masking) ---
class LightingSystem extends Component with HasGameRef<KurirGame> {
  // Prioritas 50: Dirender di atas jalanan, tapi di bawah Player (100) dan HUD.
  LightingSystem() : super(priority: 50);

  // Objek Paint yang didaur ulang (Anti-Lag)
  final Paint _darknessPaint = Paint()..color = Colors.black;
  final Paint _lightMaskPaint = Paint()
    ..blendMode = BlendMode.dstOut; // Mode untuk "melubangi" kegelapan
  final Path _lightConePath = Path();

  @override
  void render(Canvas canvas) {
    final double cycleDistance = gameRef.distanceTravelled % 3000.0;
    double darkness = 0.0;

    // Kalkulasi tingkat kegelapan yang mulus seiring berjalannya jarak
    if (cycleDistance > 800.0 && cycleDistance <= 1500.0) {
      // Sore ke malam (Kegelapan perlahan naik dari 0.0 ke 0.85)
      darkness = ((cycleDistance - 800.0) / 700.0) * 0.85;
    } else if (cycleDistance > 1500.0 && cycleDistance <= 2500.0) {
      // Malam hari pekat (Hanya terlihat sedikit bayangan)
      darkness = 0.85;
    } else if (cycleDistance > 2500.0) {
      // Subuh menuju pagi (Kegelapan memudar kembali ke 0.0)
      darkness = (1.0 - ((cycleDistance - 2500.0) / 500.0)) * 0.85;
    }

    // Hanya menggambar jika hari sudah mulai gelap untuk menghemat performa!
    if (darkness > 0.0) {
      // 1. Buat layer baru untuk menggambar. Ini penting untuk efek masking.
      canvas.saveLayer(null, Paint());

      // 2. Gambar lapisan kegelapan di seluruh layar
      _darknessPaint.color = Colors.black.withAlpha((darkness * 255).toInt());
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          gameRef
              .horizonY, // Mulai menggambar kegelapan dari garis horizon ke bawah
          gameRef.size.x,
          gameRef.size.y - gameRef.horizonY,
        ),
        _darknessPaint,
      );

      // 3. Gambar "Lubang" berbentuk sorot lampu menggunakan BlendMode.dstOut
      final player = gameRef.player;
      final playerPosition = player.position;
      final playerSize = player.size;

      // Titik pangkal lampu di posisi headlamp motor
      final headlampY = playerPosition.y - playerSize.y * 0.8;
      final headlampX = playerPosition.x;

      // Ujung sorotan lampu di depan
      final beamEndY = gameRef.horizonY + 50;
      final beamFarWidth = playerSize.x * 3.0;

      // Bentuk kerucut lampu
      _lightConePath.reset();
      _lightConePath.moveTo(headlampX, headlampY);
      _lightConePath.lineTo(headlampX + beamFarWidth, beamEndY);
      _lightConePath.lineTo(headlampX - beamFarWidth, beamEndY);
      _lightConePath.close();

      // Tambahkan efek blur pada pinggiran "lubang" agar transisinya soft
      _lightMaskPaint.maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        20.0 * darkness,
      );

      // Gambar kerucut yang akan melubangi lapisan kegelapan
      canvas.drawPath(_lightConePath, _lightMaskPaint);

      // 4. Kembalikan layer ke kanvas utama
      canvas.restore();
    }
  }
}
