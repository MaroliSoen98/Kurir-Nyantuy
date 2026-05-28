import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'dart:typed_data';
import 'components/player.dart';
import 'components/obstacle.dart';
import 'components/coin.dart';
import 'components/hud.dart';
import 'components/magnet.dart';
import 'components/shield.dart';
import 'components/spilled_coin_particle.dart';
import 'components/street_lamp.dart';
import 'components/rain_effect.dart';
import 'components/puddle.dart';

class KurirGame extends FlameGame with PanDetector, KeyboardEvents {
  late Player player;

  // Kecepatan game akan terus bertambah seiring waktu
  double gameSpeed = 1000.0; // Dipercepat sedikit untuk skala ruang 3D
  final Random _random = Random();

  late RainEffect rainEffect;
  double _weatherTimer = 0.0; // Timer cuaca

  // Flag Debugging: Set true untuk force malam, set false untuk kembali normal
  bool debugForceNight = false;
  bool debugForceRain = false; // Set true untuk force selalu hujan

  // Scoring & Progression Offline Sementara
  double distanceTravelled = 0.0;
  int currentCoins = 0;
  int totalCoinsPlayer = 0;
  double bestDistance = 0.0;
  int nextMilestone = 100;
  bool isGameOver = false;
  bool _gameOverScreenShown = false;
  bool isPaused = false; // Status apakah game sedang di-pause
  bool isMainMenu = true; // Status apakah sedang di layar awal (Demo Mode)
  int playerLives = 3;
  int _skipSpawnTicks = 0; // Jeda antar pola panjang
  double _lampDistanceCounter = 0.0; // Jarak hitung untuk spawn lampu jalan
  double _puddleDistanceCounter = 0.0; // Jarak hitung spawn genangan air

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
        'motor_mogok.png', // Gambar motor rusak/berasap
        'koin.png',
        'kucing.png',
        'ibumotor.png',
        'portal.png',
        'galian_depan.png',
        'galian_tengah.png',
        'galian_belakang.png',
        'cloud.png',
        'magnet.png',
        'shield.png',
        'puddle.png', // Tambahkan gambar puddle.png (jangan khawatir error walau gambarnya belum ada)
        'lampu_jalan_kiri.png',
        'lampu_jalan_kanan.png',
        'heart.png', // Gambar aset nyawa untuk HUD
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

    // Sistem Cuaca (Hujan)
    rainEffect = RainEffect();
    add(rainEffect);

    // Spawner rintangan setiap 1.0 detik agar jalanan tidak pernah kosong
    add(TimerComponent(period: 1.0, repeat: true, onTick: _spawnObstacle));

    // Menambahkan Indikator FPS di pojok kanan atas untuk memantau Lag
    add(
      FpsTextComponent(
        position: Vector2(size.x - 20, 50),
        anchor: Anchor.topRight,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PixelFont', // Font Retro Pixel
            color: Colors.greenAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ),
    );

    // Dihapus agar game loop tetap berjalan layaknya Live Background di Main Menu!
    // pauseEngine();
  }

  // Fungsi untuk memulai game dan musik
  Future<void> startGame() async {
    // Hapus menu utama dan tampilkan layar loading
    overlays.remove('MainMenu');
    overlays.add('Loading');

    // Beri jeda sesaat agar UI sempat me-render layar loading
    // Diberi jeda 1.5 detik untuk memberikan kesan loading yang lebih solid
    await Future.delayed(const Duration(milliseconds: 1500));

    isMainMenu = false; // Matikan mode demo background
    resetGame(); // Reset data sebelum benar-benar bermain

    resumeEngine(); // Berjaga-jaga jika ter-pause

    overlays.remove('Loading'); // Sembunyikan kembali layar loading
    overlays.add('PauseButton'); // Tampilkan tombol Pause di ujung layar
  }

  void _spawnLamps(double dt) {
    _lampDistanceCounter += gameSpeed * dt;
    if (_lampDistanceCounter > 2500.0) {
      // Munculkan tiang lampu lebih jarang (setiap jarak 2500 unit) agar game lebih ringan
      _lampDistanceCounter -= 2500.0;
      add(StreetLamp(isLeft: true, worldZ: 2500.0));
      add(StreetLamp(isLeft: false, worldZ: 2500.0));
    }
  }

  void _spawnPuddles(double dt) {
    // Puddle hanya muncul jika intensitas hujan sudah mulai terlihat
    if (rainEffect.intensity > 0.2) {
      _puddleDistanceCounter += gameSpeed * dt;
      if (_puddleDistanceCounter > 1500.0) {
        // Frekuensi genangan dikurangi drastis
        // Munculkan genangan air dengan jarak acak yang lebih jarang
        _puddleDistanceCounter -= (1500.0 + _random.nextDouble() * 1500.0);

        // Munculkan di titik X aspal secara bebas/acak (tidak terikat lajur -1, 0, 1)
        double randX = (_random.nextDouble() * 540) - 270;

        // Spawn di Z=2000.0 (Tepat sebelum rintangan baru di-spawn di 2200.0)
        // Ini memungkinkan kita memindai rintangan yang sudah ada di layar secara akurat.
        double randZ = 2000.0;

        // Cek overlap dengan rintangan yang SUDAH ADA sebelum menambahkan genangan
        bool isSafe = true;
        for (final child in children) {
          if (child is Obstacle && !child.isRemoving) {
            // Beri jarak toleransi agar genangan tidak terlalu menempel ke rintangan
            double obsLeft = child.worldX - (child.baseSize.x / 2) - 40.0;
            double obsRight = child.worldX + (child.baseSize.x / 2) + 40.0;
            double obsFront = child.worldZ - 60.0;
            double obsBack = child.worldZ + child.depthZ + 60.0;

            double pLeft = randX - 90.0; // baseSize.x / 2
            double pRight = randX + 90.0;
            double pFront = randZ - 30.0; // baseSize.y / 2
            double pBack = randZ + 30.0;

            // Jika kotak genangan bersinggungan dengan kotak rintangan, batalkan spawn!
            if (pRight > obsLeft &&
                pLeft < obsRight &&
                pBack > obsFront &&
                pFront < obsBack) {
              isSafe = false;
              break;
            }
          }
        }

        // Hanya tambahkan ke layar jika spot tersebut 100% kosong dari rintangan
        if (isSafe) {
          add(Puddle(worldX: randX, worldZ: randZ, baseSize: Vector2(180, 60)));
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (debugForceRain) {
      rainEffect.isRaining = true;
    } else {
      // Logika Perubahan Cuaca Secara Berkala (30 detik sekali agar tidak terus-terusan dicek)
      _weatherTimer += dt;
      if (_weatherTimer > 30.0) {
        _weatherTimer -= 30.0;
        if (!rainEffect.isRaining) {
          // 10% peluang hujan turun tiba-tiba
          if (_random.nextDouble() < 0.10) {
            rainEffect.isRaining = true;
          }
        } else {
          // 60% peluang hujan reda jika sedang hujan (supaya hujannya tidak kelamaan)
          if (_random.nextDouble() < 0.60) {
            rainEffect.isRaining = false;
          }
        }
      }
    }

    if (isMainMenu) {
      // Mode Background: Jalanan dan awan bergerak konstan tapi skor tidak dihitung permanen
      distanceTravelled += (gameSpeed * dt) / 100.0;
      _spawnLamps(dt);
      _spawnPuddles(dt);
      return; // Hentikan logika lain (gak nambah susah)
    }

    if (isGameOver) {
      // Efek motor melambat sebelum berhenti total (Cinematic Crash)
      if (gameSpeed > 0) {
        gameSpeed -=
            2500.0 * dt; // Daya pengereman (Makin besar, makin cepat berhenti)
        if (gameSpeed <= 0) {
          gameSpeed = 0;
          if (!_gameOverScreenShown) {
            _showGameOverScreen();
          }
        }
      }
      // Jalanan tetap bergerak perlahan lalu berhenti mengikuti gameSpeed
      distanceTravelled += (gameSpeed * dt) / 100.0;
      _spawnLamps(dt);
      _spawnPuddles(dt);
      return; // Hentikan update penambahan kecepatan normal dan milestone
    }

    // Update skor meter berdasarkan kecepatan gerak (Disesuaikan rasio realita)
    distanceTravelled += (gameSpeed * dt) / 100.0;
    gameSpeed += 5.0 * dt; // Tantangan meningkat berkala sedikit lebih cepat
    _spawnLamps(dt); // Selalu jalankan spawner lampu
    _spawnPuddles(dt); // Selalu jalankan spawner puddle (muncul jika hujan)

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
    bool addShieldAtPeak = false,
  }) {
    for (int i = 0; i < count; i++) {
      double t = (count > 1) ? (i / (count - 1)) : 0.5;
      // Puncak arc dirapikan (diturunkan ke 120) agar lengkungan koin sangat natural dengan tinggi lompatan pemain
      double arcY = -120.0 * sin(t * pi);
      double currentZ = startZ + (endZ - startZ) * t;

      if ((addMagnetAtPeak || addShieldAtPeak) && i == count ~/ 2) {
        if (addMagnetAtPeak) {
          add(
            Magnet(worldX: laneX, worldZ: currentZ, baseSize: Vector2(25, 25))
              ..worldY = arcY - 15.0,
          );
        } else if (addShieldAtPeak) {
          add(
            ShieldPowerUp(
              worldX: laneX,
              worldZ: currentZ,
              baseSize: Vector2(25, 25),
            )..worldY = arcY - 15.0,
          );
        }
      } else {
        add(
          Coin(worldX: laneX, worldZ: currentZ, baseSize: Vector2(40, 40))
            ..worldY = arcY - 15.0,
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
    bool addShield = false,
  }) {
    int powerUpIndex = (addMagnet || addShield)
        ? (count ~/ 2)
        : -1; // Item selalu di tengah barisan jika ada
    for (int i = 0; i < count; i++) {
      double currentZ = startZ + (i * spacing);
      if (i == powerUpIndex) {
        if (addMagnet) {
          add(
            Magnet(worldX: laneX, worldZ: currentZ, baseSize: Vector2(25, 25)),
          );
        } else if (addShield) {
          add(
            ShieldPowerUp(
              worldX: laneX,
              worldZ: currentZ,
              baseSize: Vector2(25, 25),
            ),
          );
        }
      } else {
        add(Coin(worldX: laneX, worldZ: currentZ, baseSize: Vector2(40, 40)));
      }
    }
  }

  void _spawnObstacle() {
    if (isGameOver || isMainMenu)
      return; // Jangan munculkan rintangan/koin saat di Main Menu

    // Peluang 4% (diperkecil) untuk memunculkan Magnet agar item terasa lebih berharga dan tidak berlebihan
    bool spawnMagnet = _random.nextDouble() < 0.04;
    // Peluang 3% untuk memunculkan Shield, tapi hanya jika magnet tidak muncul
    bool spawnShield = !spawnMagnet && _random.nextDouble() < 0.03;

    // Pindahkan deklarasi konstanta ke atas agar bisa digunakan secara universal
    final double laneSpacing = 180.0;
    final double startZ =
        2200.0; // Dimulai sedikit lebih jauh agar pola panjang tertata rapi

    // Beri jeda kosong jika pola sebelumnya sangat panjang agar tidak tumpang tindih
    if (_skipSpawnTicks > 0) {
      _skipSpawnTicks--;

      // Variasi "Filler": 50% Barisan Koin Panjang, 50% Blok Koin ala Subway Surfer
      if (_random.nextBool()) {
        final double fillerLane = (_random.nextInt(3) - 1).toDouble();
        _spawnCoinLine(
          fillerLane * laneSpacing,
          startZ,
          6, // Koin dirapikan menjadi 6 baris dengan jarak konstan
          spacing: 150.0,
          addMagnet: spawnMagnet,
          addShield: spawnShield,
        );
      } else {
        // Blok Koin Lebar 3 Lajur x 3 Baris
        for (double l in [-1.0, 0.0, 1.0]) {
          _spawnCoinLine(
            l * laneSpacing,
            startZ,
            3,
            spacing: 150.0,
            addMagnet: (l == 0.0) ? spawnMagnet : false,
            addShield: (l == 0.0) ? spawnShield : false,
          );
        }
      }
      return;
    }

    final int pattern = _random.nextInt(7); // Acak 1 dari 7 Skenario Pola

    switch (pattern) {
      case 0: // POLA 0: Ular Koin (Melengkung) & Rintangan Kejutan
        final curveLanes = [1.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0];
        final startSide = _random.nextBool() ? 1.0 : -1.0;
        for (int i = 0; i < curveLanes.length; i++) {
          add(
            Coin(
              worldX: curveLanes[i] * startSide * laneSpacing,
              worldZ: startZ + (i * 150.0), // Jarak grid koin sempurna (150.0)
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
        _spawnCoinArc(
          0.0,
          startZ + 1050.0,
          startZ +
              1650.0, // Dibulatkan agar titik lompat dan jatuh koin sejajar di grid 150
          5,
          addMagnetAtPeak: spawnMagnet,
          addShieldAtPeak: spawnShield,
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
          startZ - 300.0, // Koin dimunculkan di depan portal secara simetris
          5,
          spacing: 150.0,
          addMagnet: spawnMagnet,
          addShield: spawnShield,
        );
        break;

      case 2: // POLA 2: Emak-Emak Zig-Zag + Koin Penuntun Celah Aman
        add(
          Obstacle(
            worldX: -laneSpacing,
            worldZ: startZ,
            baseSize: Vector2(140, 120),
            canDrift: false, // Dimatikan agar tidak nge-drift ke koin penuntun
          ),
        );
        // Barisan 3 koin penuntun untuk celah aman pertama
        _spawnCoinLine(laneSpacing, startZ - 150.0, 3, spacing: 150.0);

        add(
          Obstacle(
            worldX: laneSpacing,
            worldZ: startZ + 600.0, // Diperjauh agar tidak menumpuk
            baseSize: Vector2(140, 120),
            canDrift: false,
          ),
        );
        // Barisan 3 koin penuntun untuk celah aman kedua
        _spawnCoinLine(
          -laneSpacing,
          startZ + 450.0,
          3,
          spacing: 150.0,
          addMagnet: spawnMagnet,
          addShield: spawnShield,
        ); // Selipkan magnet di jalur aman ini

        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ + 1200.0, // Diperjauh agar pemain punya waktu reaksi
            baseSize: Vector2(140, 120),
            canDrift: false,
          ),
        );
        // Barisan 3 koin penuntun untuk celah aman ketiga
        _spawnCoinLine(laneSpacing, startZ + 1050.0, 3, spacing: 150.0);

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
          startZ,
          9, // Koin menutupi kedalaman terowongan sepanjang 1200 dengan presisi (9 x 150 = 1200)
          spacing: 150.0,
          addMagnet: spawnMagnet,
          addShield: spawnShield,
        );

        // Jebakan emak-emak statis di ujung koin! Pemain harus sigap menghindar
        add(
          Obstacle(
            worldX: 0.0,
            worldZ: startZ + 1500.0, // Beri jeda lebih usai koin terakhir
            baseSize: Vector2(140, 120),
            canDrift: false,
          ),
        );
        _skipSpawnTicks = 2;
        break;

      case 4: // POLA 4: Leap of Faith (Koin Melayang di atas Galian!)
        final double emptyLane = (_random.nextInt(3) - 1).toDouble();
        bool powerUpPlaced = false;
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
            _spawnCoinArc(
              l * laneSpacing,
              startZ - 150.0,
              startZ +
                  450.0, // Melengkung mulus mendarat di grid 150 berikutnya
              5,
              addMagnetAtPeak: (spawnMagnet && !powerUpPlaced),
              addShieldAtPeak: (spawnShield && !powerUpPlaced),
            );
            powerUpPlaced = true; // Cukup 1 power up per pola
          }
        }
        break;

      case 5: // POLA 5: The Wall (2 Lajur diblokir tembok, 1 lajur aman ditandai Koin)
        final double safeLane5 = (_random.nextInt(3) - 1).toDouble();
        for (double l in [-1.0, 0.0, 1.0]) {
          if (l == safeLane5) {
            _spawnCoinLine(
              l * laneSpacing,
              startZ - 300.0, // Koin sejajar rapi dari awal sebelum tembok
              4,
              spacing: 150.0,
              addMagnet: spawnMagnet,
              addShield: spawnShield,
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
        _spawnCoinArc(
          0.0,
          startZ - 150.0,
          startZ + 450.0,
          5,
          addMagnetAtPeak: spawnMagnet,
          addShieldAtPeak: spawnShield,
        );

        add(
          Obstacle(
            worldX: 0.0,
            worldZ:
                startZ + 900.0, // Majukan portal agar pas di kelipatan grid 150
            baseSize: Vector2(600, 80),
            isFloating: true,
          ),
        );

        final double sideLane6 = _random.nextBool() ? -1.0 : 1.0;
        _spawnCoinLine(
          -sideLane6 * laneSpacing,
          startZ + 1200.0, // Penuntun muncul tepat usai pemain keluar di portal
          4,
          spacing: 150.0,
        );
        add(
          Obstacle(
            worldX: sideLane6 * laneSpacing,
            worldZ: startZ + 1500.0,
            baseSize: Vector2(140, 120),
            canDrift:
                false, // Matikan drift karena ini reflex run yang sangat cepat
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

    // Sistem Penalti Koin (Koin Tumpah ala Sonic)
    if (currentCoins > 0) {
      // Hitung jumlah koin riil yang tumpah (maksimal 50, atau sisa koin jika kurang dari 50)
      int coinsToSpill = min(currentCoins, 50);
      currentCoins -= 50;
      if (currentCoins < 0) currentCoins = 0; // Pastikan koin tidak minus

      // Batasi visual partikel koin maksimal 30 agar tidak lag (Frame Drop) saat tumpah banyak
      add(
        SpilledCoinParticle(
          position: player.position.clone(),
          sprite: Sprite(images.fromCache('koin.png')), // Kirim aset koin
          amount: min(coinsToSpill, 30),
        ),
      );
    }

    if (playerLives <= 0) {
      isGameOver = true;
      overlays.remove('PauseButton'); // Sembunyikan tombol pause
    }
  }

  Future<void> _showGameOverScreen() async {
    _gameOverScreenShown = true;
    player.showMogok(); // Ganti sprite motor menjadi mogok sebelum game membeku

    // Beri jeda 1.5 detik agar pemain bisa menikmati animasi motor berhenti dan mogok
    await Future.delayed(const Duration(milliseconds: 1500));

    pauseEngine(); // Hentikan game loop secara total

    // Update rekaman skor tinggi
    if (distanceTravelled > bestDistance) {
      bestDistance = distanceTravelled;
      prefs.setDouble('bestDistance', bestDistance); // Simpan ke storage
    }

    totalCoinsPlayer += currentCoins;
    prefs.setInt('totalCoinsPlayer', totalCoinsPlayer); // Simpan ke storage

    overlays.add('GameOver'); // Munculkan Widget Layar Penuh
  }

  void resetGame() {
    isGameOver = false;
    _gameOverScreenShown = false;
    isPaused = false;
    playerLives = 3;
    distanceTravelled = 0.0;
    currentCoins = 0;
    gameSpeed = 1000.0;
    nextMilestone = 100;
    _lampDistanceCounter = 0.0;
    _puddleDistanceCounter = 0.0;
    _weatherTimer = 0.0;
    rainEffect.isRaining = false;
    rainEffect.intensity = 0.0; // Langsung hapus hujan saat mati
    player.reset(); // Reset seluruh status pemain dan bersihkan efek

    // Bersihkan rintangan & koin dari sisa permainan sebelumnya
    // Menggunakan toList() memastikan iterasi aman sebelum penghapusan.
    removeAll(children.whereType<Obstacle>().toList());
    removeAll(children.whereType<Coin>().toList());
    removeAll(children.whereType<Magnet>().toList());
    removeAll(children.whereType<ShieldPowerUp>().toList());
    removeAll(children.whereType<SpilledCoinParticle>().toList());
    removeAll(children.whereType<StreetLamp>().toList());
    removeAll(children.whereType<Puddle>().toList());
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

    if (isPaused || isMainMenu || isGameOver)
      return; // Nonaktifkan kontrol dari pemain saat di-pause atau di menu

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
      if (isGameOver)
        return super.onKeyEvent(
          event,
          keysPressed,
        ); // Abaikan semua input keyboard jika mati

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

      if (isPaused || isMainMenu)
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
      final cloudImg = await gameRef.images.load('cloud.png');
      _cloudSprite = Sprite(cloudImg);
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
    canvas.drawPath(_renderPath, roadPaint);

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

  // [OPTIMALISASI 60 FPS] Simpan List Warna secara statis agar sistem tidak perlu
  // membuang dan membuat array/list baru sebanyak 60 kali setiap detiknya!
  static final List<Color> _holeColors = [
    Colors.black.withOpacity(1.0),
    Colors.black.withOpacity(0.95),
    Colors.black.withOpacity(0.0),
  ];
  static final List<double> _holeStops = const [0.0, 0.75, 1.0];

  static final List<Color> _beamColors = [
    Colors.white.withOpacity(0.30),
    Colors.white.withOpacity(0.15),
    Colors.white.withOpacity(0.0),
  ];
  static final List<double> _beamStops = const [0.0, 0.75, 1.0];

  // --- Variabel Cache Shader (Optimalisasi FPS Mencegah Lag Tiba-Tiba) ---
  double _cachedYNear = -9999.0;
  double _cachedYFar = -9999.0;

  // Menggunakan shader gradasi sehingga warna solid dihapus
  static final Paint _lampHolePaint = Paint()..blendMode = BlendMode.dstOut;
  static final Paint _lampBeamPaint = Paint();
  final Path _lampBeamPath = Path();

  // --- Cache Kabut (Fog) Horizon ---
  final Paint _fogPaint = Paint();
  double _cachedFogDarkness = -1.0;

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

      const double nearBeamWidth = 25.0; // Sedikit dilebarkan di pangkal
      const double farBeamWidth =
          1700.0; // Diperlebar lagi agar jangkauan pandangan ke samping lebih luas

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

      // [OPTIMALISASI FPS TERBESAR]: Hanya perbarui objek UI Gradient (Sangat berat di GPU)
      // jika posisi lampu benar-benar berubah saat pemain sedang melompat atau menunduk!
      if ((yNear - _cachedYNear).abs() > 0.5 ||
          (yFar - _cachedYFar).abs() > 0.5) {
        _holePunchPaint.shader = ui.Gradient.linear(
          Offset(0, yNear), // Titik asal (Motor)
          Offset(0, yFar), // Ujung cahaya (Horizon)
          _holeColors,
          _holeStops,
        );
        _beamPaint.shader = ui.Gradient.linear(
          Offset(0, yNear),
          Offset(0, yFar),
          _beamColors,
          _beamStops,
        );
        _cachedYNear = yNear;
        _cachedYFar = yFar;
      }

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

      // --- RENDER CAHAYA LAMPU JALAN ---
      final lamps = gameRef.children.whereType<StreetLamp>();
      for (final lamp in lamps) {
        if (lamp.worldZ < -100 || lamp.worldZ > 4000)
          continue; // Abaikan jika di luar batas pandangan layar

        final scale = gameRef.getScale(lamp.worldZ);
        final lampScreenX = (gameRef.size.x / 2) + (lamp.worldX * scale);
        final lampScreenY =
            gameRef.horizonY + ((gameRef.cameraHeight + lamp.worldY) * scale);

        // Posisi bohlam (Di atas lampu, ditarik sedikit menjorok ke arah jalan aspal)
        final inwardOffset = lamp.isLeft ? (50.0 * scale) : (-50.0 * scale);
        final bulbX = lampScreenX + inwardOffset;
        final bulbY =
            lampScreenY - (335.0 * scale); // Mengikuti proporsi tinggi tiang

        // Titik tengah jatuhnya cahaya di aspal (Ditarik agak ke tengah jalan)
        final groundCenterX =
            lampScreenX + (lamp.isLeft ? (120.0 * scale) : (-120.0 * scale));
        final groundCenterY = lampScreenY;

        // Dimensi oval area cahaya di tanah (Perspektif 3D lonjong)
        final poolWidth =
            160.0 *
            scale; // Diperbesar sedikit agar sorotan terasa lebih luas tapi tidak berlebihan
        final poolHeight = 45.0 * scale;
        final poolCenter = Offset(groundCenterX, groundCenterY);

        // Bikin Matrix agar gradient bulat pipih/lonjong mengikuti perspektif aspal
        final ellipseMatrix = vmath.Matrix4.identity()
          ..translate(poolCenter.dx, poolCenter.dy)
          ..scale(1.0, poolHeight / poolWidth, 1.0)
          ..translate(-poolCenter.dx, -poolCenter.dy);

        // 1. Buat Lubang Malam (Hanya di area aspal) dengan Radial Gradient!
        _lampHolePaint.shader = ui.Gradient.radial(
          poolCenter,
          poolWidth,
          [
            Colors.black.withOpacity(0.35), // Tengah terang (melubangi)
            Colors.black.withOpacity(0.0), // Tepi memudar halus
          ],
          const [0.0, 1.0],
          TileMode.clamp,
          ellipseMatrix.storage, // Transformasi lonjong (3D)
        );

        final poolRect = Rect.fromCenter(
          center: poolCenter,
          width: poolWidth * 2,
          height: poolHeight * 2,
        );
        canvas.drawOval(poolRect, _lampHolePaint);

        // 2. Buat Kerucut Cahaya Senter (Cone) di udara dari bohlam ke tanah
        _lampBeamPath.reset();
        _lampBeamPath.moveTo(
          bulbX,
          bulbY,
        ); // Titik asal (ujung atas/Puncak Kerucut)
        _lampBeamPath.lineTo(
          groundCenterX - poolWidth,
          groundCenterY,
        ); // Tepi kiri bawah di tanah

        // Lengkungan alas kerucut (mengikuti kurva oval depan pendaran tanah)
        _lampBeamPath.quadraticBezierTo(
          groundCenterX,
          groundCenterY + poolHeight,
          groundCenterX + poolWidth,
          groundCenterY,
        );
        _lampBeamPath.close();

        _lampBeamPaint.shader = ui.Gradient.linear(
          Offset(bulbX, bulbY),
          poolCenter,
          [
            const Color(0xFFFFF5D6).withOpacity(0.12), // Terang di atas
            const Color(0xFFFFF5D6).withOpacity(0.0), // Memudar di bawah
          ],
        );
        canvas.drawPath(_lampBeamPath, _lampBeamPaint);

        // 3. Pendar Kuning di aspal (Radial Gradient lonjong)
        _lampBeamPaint.shader = ui.Gradient.radial(
          poolCenter,
          poolWidth,
          [
            const Color(
              0xFFFFF5D6,
            ).withOpacity(0.06), // Kuning lembut di tengah
            const Color(0xFFFFF5D6).withOpacity(0.0), // Memudar di tepi
          ],
          const [0.0, 1.0],
          TileMode.clamp,
          ellipseMatrix.storage,
        );
        canvas.drawOval(poolRect, _lampBeamPaint);
      }

      canvas.restore();

      // --- RENDER KABUT HORIZON (FOG ATMOSFERIK) ---
      // Digambar setelah semua objek selesai untuk menyamarkan batas horizon,
      // rintangan yang baru muncul, dan menyatukan ujung sorot lampu motor.
      final fogTop = gameRef.horizonY - 120.0;
      final fogBottom = gameRef.horizonY + 180.0;
      final fogRect = Rect.fromLTRB(0, fogTop, gameRef.size.x, fogBottom);

      // [OPTIMALISASI FPS] Shader kabut hanya diperbarui jika nilai kegelapan berubah (mencegah spam render)
      if ((_cachedFogDarkness - darkness).abs() > 0.02) {
        _fogPaint.shader = ui.Gradient.linear(
          Offset(0, fogTop),
          Offset(0, fogBottom),
          [
            const Color(0xFF0A0F24).withOpacity(0.0), // Langit atas transparan
            const Color(0xFF1E284A).withOpacity(
              darkness * 0.95,
            ), // Pusat kabut di horizon (Biru gelap malam)
            const Color(0xFF0A0F24).withOpacity(0.0), // Aspal bawah transparan
          ],
          const [
            0.0,
            0.45,
            1.0,
          ], // Titik tertebal (0.45) disejajarkan pas dengan garis horizon
        );
        _cachedFogDarkness = darkness;
      }

      canvas.drawRect(fogRect, _fogPaint); // Sangat ringan, hanya 1 drawRect
    }
  }
}
