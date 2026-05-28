import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';
import '../kurir_game.dart';
import 'obstacle.dart';
import 'coin.dart';
import 'coin_particle.dart';
import 'magnet.dart';
import 'shield.dart';
import 'dust_particle.dart';
import 'puddle.dart';
import 'water_splash_particle.dart';

class Player extends SpriteComponent with HasGameRef<KurirGame> {
  // -1: Kiri, 0: Tengah, 1: Kanan
  int currentLane = 0;
  double laneSpacing =
      175.0; // Disesuaikan agar posisi motor terasa lebih di tengah lajur

  // Koordinat Posisi di Ruang 3D
  double worldX = 0;
  double worldY = 0;
  double worldZ = 0; // Pemain konstan menetap di kedalaman 0
  double targetWorldX = 0;

  // Fisika Lompat (Jump)
  double velocityY = 0;
  bool isJumping = false;
  bool hasMovedInAir = false; // Membatasi pindah lajur di udara

  // Fisika Nunduk (Slide)
  bool isSliding = false;
  double slideTimer = 0;
  double slideYOffset = 0; // Offset visual saat nunduk
  bool isMogok = false; // Status apakah motor sedang rusak
  double shakeTimer = 0; // Timer untuk efek goncangan tanpa membebani posisi 3D
  double _dustTimer = 0; // Timer pengeluaran partikel debu

  bool hasShield = false; // Status Shield/Booster Aktif
  double shieldDuration = 0; // Durasi shield
  bool isInvincible = false;
  double invincibilityTimer = 0;

  // Status Power Up Magnet
  bool isMagnetActive = false;
  double magnetDuration = 0;
  double _magnetWaveTimer = 0; // Timer khusus untuk animasi gelombang magnet

  // [OPTIMALISASI FPS] Pre-alokasi memori untuk Paint Aura Magnet
  static final Paint _auraPaint = Paint()
    ..color = Colors.lightBlueAccent.withAlpha(120)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;

  // [OPTIMALISASI FPS] Pre-alokasi memori untuk Paint Aura Shield
  static final Paint _shieldAuraPaint = Paint()
    ..color = Colors.greenAccent.withAlpha(120)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;

  // Menyimpan referensi efek damage agar bisa dibatalkan secara instan walau masih di dalam antrean (Add Queue) Flame
  final List<Effect> _damageEffects = [];

  final Vector2 baseSize = Vector2(
    110,
    150,
  ); // Diperbesar agar proporsional di lajur

  // Variabel untuk menyimpan sprite yang sudah di-load agar bisa diganti-ganti
  Sprite? _spriteNormal;
  Sprite? _spriteNunduk;
  Sprite? _spriteMogok;

  // Untuk sementara kita pakai kotak warna sebagai placeholder aset pixel motor
  Player()
    : super(
        anchor: Anchor.bottomCenter, // Point of scale ada di tapak ban (bawah)
        priority:
            100, // Memastikan kurir selalu digambar paling depan (di atas rintangan)
      );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Mengambil gambar dari Cache secara Sinkron/Instan (Tanpa Await)
    try {
      _spriteNormal = Sprite(gameRef.images.fromCache('motor.png'));
      _spriteNunduk = Sprite(gameRef.images.fromCache('motor_nunduk.png'));
      _spriteMogok = Sprite(gameRef.images.fromCache('motor_mogok.png'));
      sprite = _spriteNormal; // Atur sprite awal ke kondisi normal
    } catch (e) {
      debugPrint("Sprite motor tidak ditemukan di cache: $e");
    }
    paint.filterQuality = FilterQuality.none; // Mencegah pixel art menjadi blur
  }

  // Memunculkan sprite motor mogok saat game over
  void showMogok() {
    if (_spriteMogok != null) {
      sprite = _spriteMogok;
      slideYOffset =
          0; // Pastikan posisi visual tidak turun seperti saat nunduk
      isMogok = true; // Kunci perubahan sprite di fungsi update

      scale.setValues(
        1.3,
        1.3,
      ); // Perbesar skala gambar mogok (30%) agar terlihat seimbang dengan motor aslinya
    }
  }

  // Fungsi untuk mengembalikan kondisi pemain ke awal seperti baru
  void reset() {
    currentLane = 0;
    targetWorldX = 0;
    worldX = 0;
    worldY = 0;
    velocityY = 0;
    isJumping = false;
    hasMovedInAir = false;
    isSliding = false;
    slideTimer = 0;
    slideYOffset = 0;
    isMogok = false; // Matikan status mogok saat direstart
    shakeTimer = 0; // Hentikan efek getaran tersisa
    hasShield = false;
    shieldDuration = 0;
    isInvincible = false;
    invincibilityTimer = 0;
    isMagnetActive = false;
    magnetDuration = 0;
    angle = 0;

    // Membatalkan efek yang masih mengantre di memory (Add Queue) akibat game over mendadak
    for (final effect in _damageEffects) {
      effect.removeFromParent();
    }
    _damageEffects.clear();

    // Hapus semua efek visual yang membeku saat game over
    removeAll(children.whereType<Effect>().toList());
    scale.setValues(1.0, 1.0); // Kembalikan ukuran motor ke normal
    paint.color = Colors.white; // Reset warna/transparan
    paint.colorFilter = null; // Hapus sisa warna merah
  }

  void moveLeft() {
    if (isJumping && hasMovedInAir) return; // Cegah pindah lajur ganda di udara
    if (currentLane > -1) {
      currentLane--;
      targetWorldX = currentLane * laneSpacing;
      if (isJumping) hasMovedInAir = true; // Tandai sudah pindah di udara
    }
  }

  void moveRight() {
    if (isJumping && hasMovedInAir) return; // Cegah pindah lajur ganda di udara
    if (currentLane < 1) {
      currentLane++;
      targetWorldX = currentLane * laneSpacing;
      if (isJumping) hasMovedInAir = true; // Tandai sudah pindah di udara
    }
  }

  void jump() {
    if (!isJumping) {
      isJumping = true;
      hasMovedInAir = false; // Reset batas gerak saat baru melompat
      velocityY =
          -950; // Gaya dorong ke atas dikurangi agar tidak terlalu tinggi
    }
  }

  void slide() {
    if (!isJumping && !isSliding) {
      isSliding = true;
      slideTimer = 0.8; // Durasi nunduk 0.8 detik
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Hitung jarak sisa ke lajur tujuan
    final double dx = targetWorldX - worldX;

    // Lerp perpindahan lajur dengan perlindungan terhadap Lag Spike / initial loading
    final double lerpFactor = 10 * dt;
    if (lerpFactor >= 1.0) {
      worldX = targetWorldX; // Anti-overshoot, motor tidak akan goyang di awal
    } else {
      worldX += dx * lerpFactor;
    }

    // Efek Motion Animasi Belok (Miring/Lean) - Maksimal miring ~15 derajat (0.25 radian)
    angle = (dx * 0.003).clamp(-0.25, 0.25);

    // Logika Nunduk
    if (!isMogok) {
      if (isSliding) {
        sprite = _spriteNunduk; // Ganti ke sprite menunduk
        slideYOffset =
            35.0; // Turunkan posisi visual pemain agar terlihat 'di kolong'
        slideTimer -= dt;
        if (slideTimer <= 0) {
          isSliding = false; // Kembali berdiri
        }
      } else {
        sprite = _spriteNormal; // Kembali ke sprite normal
        slideYOffset = 0; // Kembalikan posisi visual
      }
    }

    // Logika Kebal Sesaat (Invincibility)
    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
      }
    }

    // Logika Power Up Shield
    if (hasShield) {
      shieldDuration -= dt;
      if (shieldDuration <= 0) {
        hasShield = false;
      }
    }

    // Logika Power Up Magnet (Hisap Koin)
    if (isMagnetActive) {
      _magnetWaveTimer += dt;
      magnetDuration -= dt;
      if (magnetDuration <= 0) {
        isMagnetActive = false;
      } else {
        // Telusuri koin-koin dan hisap mereka jika jaraknya masuk jangkauan
        for (final child in gameRef.children) {
          if (child is Coin && !child.isRemoving) {
            if (child.worldZ > worldZ && child.worldZ < worldZ + 1500.0) {
              double pullSpeed = 8.0 * dt;
              child.worldX += (worldX - child.worldX) * pullSpeed;
              child.worldY += (worldY - child.worldY) * pullSpeed;
              child.worldZ -=
                  (gameRef.gameSpeed * 0.8) *
                  dt; // Tarik ekstra cepat ke arah pemain!
            }
          }
        }
      }
    }

    // Fisika Gravitasi saat melompat
    if (isJumping) {
      worldY += velocityY * dt;
      velocityY += 3500 * dt; // Gravitasi menarik jatuh
      if (worldY >= 0) {
        // Menyentuh tanah kembali
        worldY = 0;
        isJumping = false;
      }
    }

    // Proyeksi skala dari ruang 3D ke posisi Layar 2D
    final scale = gameRef.getScale(worldZ);

    // Hitung goncangan (shake) jika timer aktif
    double shakeX = 0;
    if (shakeTimer > 0) {
      shakeTimer -= dt;
      shakeX = sin(shakeTimer * 50) * 15;
    }

    // Gunakan setValues alih-alih Vector2() baru setiap frame (Mencegah Lag Memory)
    size.setValues(baseSize.x * scale, baseSize.y * scale);
    position.setValues(
      (gameRef.size.x / 2) + (worldX * scale) + shakeX,
      gameRef.horizonY +
          ((gameRef.cameraHeight + worldY + slideYOffset) * scale),
    );

    // --- EFEK PARTIKEL DEBU SAAT NUNDUK ---
    // Hanya munculkan debu jika motor sedang nunduk dan berada di tanah (worldY == 0)
    if (isSliding && worldY >= 0) {
      _dustTimer -= dt;
      if (_dustTimer <= 0) {
        gameRef.add(DustParticle(position: position.clone()));
        _dustTimer =
            0.05; // Atur jeda seberapa sering debu keluar (Makin kecil makin tebal)
      }
    }

    // --- LOGIKA TABRAKAN 3D MANUAL (SUPER RINGAN & 0 DELAY) ---
    // Menggantikan 100% sistem deteksi Quadtree Flame yang sangat membebani HP
    for (final child in gameRef.children) {
      if (child is Obstacle) {
        if (isInvincible || child.isRemoving) continue; // Abaikan jika kebal

        final obstacle = child;

        // 1. Cek Sumbu Z (Kedalaman / Depan-Belakang)
        bool inZRange =
            worldZ >=
                (obstacle.worldZ -
                    40.0) && // Dipersempit agar motor menabrak tepat di body
            worldZ <= (obstacle.worldZ + obstacle.depthZ + 40.0);
        if (!inZRange) continue;

        // 2. Cek Sumbu X (Lajur Kiri/Tengah/Kanan)
        double obstacleWidth =
            obstacle.baseSize.x *
            0.6; // Hitbox rintangan dibuat lebih kecil (mengabaikan ruang kosong pinggiran gambar)
        double obstacleLeft = obstacle.worldX - (obstacleWidth / 2);
        double obstacleRight = obstacle.worldX + (obstacleWidth / 2);

        double playerWidth =
            baseSize.x *
            0.4; // Hitbox badan motor dirampingkan mengikuti visual motor
        double playerLeft = worldX - (playerWidth / 2);
        double playerRight = worldX + (playerWidth / 2);

        bool inXRange =
            playerRight > obstacleLeft && playerLeft < obstacleRight;
        if (!inXRange) continue;

        // 3. Cek Sumbu Y (Ketinggian / Lompat / Nunduk)
        bool isHit = false;
        if (obstacle.isFloating) {
          // PORTAL: Wajib nunduk. Lompat atau diam = nabrak
          isHit = !isSliding;
        } else {
          if (obstacle.isSmall) {
            // GALIAN: Hitbox bawah dirapatkan, pemain harus melompat melebihi aspal (ketinggian > 40)
            isHit = worldY > -40.0;
          } else {
            // RINTANGAN NORMAL (Emak-emak & Tembok):
            // Pemain harus melompat cukup tinggi (> 100) jika ingin melewatinya dari atas
            isHit = worldY > -100.0;
          }
        }

        // 4. Eksekusi Damage
        if (isHit) {
          if (hasShield) {
            obstacle.removeFromParent();
          } else {
            _triggerShake();
            gameRef.playerHit();
          }
          break; // Stop loop jika sudah terkena hit
        }
      } else if (child is Coin) {
        if (child.isRemoving) continue;

        // Jarak deteksi (Hitbox) Koin yang lebih presisi (Harus tersentuh)
        if ((worldZ - child.worldZ).abs() < 60.0 &&
            (worldX - child.worldX).abs() < 50.0 &&
            (worldY - child.worldY).abs() < 60.0) {
          gameRef.currentCoins++;
          gameRef.add(
            CoinParticle(position: child.position, sprite: child.sprite!),
          );
          child.removeFromParent();
        }
      } else if (child is Magnet) {
        if (child.isRemoving) continue;

        if ((worldZ - child.worldZ).abs() < 60.0 &&
            (worldX - child.worldX).abs() < 50.0 &&
            (worldY - child.worldY).abs() < 60.0) {
          isMagnetActive = true;
          magnetDuration = 10.0; // Aktif selama 10 detik penuh
          child.removeFromParent();
        }
      } else if (child is ShieldPowerUp) {
        if (child.isRemoving) continue;

        if ((worldZ - child.worldZ).abs() < 60.0 &&
            (worldX - child.worldX).abs() < 50.0 &&
            (worldY - child.worldY).abs() < 60.0) {
          hasShield = true;
          shieldDuration = 10.0; // Kebal selama 10 detik penuh
          child.removeFromParent();
        }
      } else if (child is Puddle) {
        if (child.isRemoving || child.hasSplashed) continue;

        // Cek apakah ban motor menyentuh genangan air (Hitbox X dan Z, serta Y > -20.0 agar tidak terpicu saat melompat)
        if ((worldZ - child.worldZ).abs() < 60.0 &&
            (worldX - child.worldX).abs() < (child.baseSize.x / 2) &&
            worldY > -20.0) {
          // Syarat mutlak: motor harus menyentuh aspal
          child.hasSplashed = true;
          gameRef.add(WaterSplashParticle(position: position.clone()));
        }
      }
    }
  }

  void _triggerShake() {
    // Alih-alih menggunakan MoveEffect yang bentrok dengan sistem koordinat 3D kita,
    // kita atur timer goncangan manual yang sangat ringan dan mulus.
    shakeTimer = 0.2;
  }

  void triggerInvincibility() {
    isInvincible = true;
    invincibilityTimer = 1.5; // Kebal selama 1.5 detik

    // Bersihkan penumpukan efek jika tabrakan beruntun
    for (final effect in _damageEffects) {
      effect.removeFromParent();
    }
    _damageEffects.clear();

    // Efek Kedip-kedip (Blinking)
    final opacityEffect = OpacityEffect.to(
      0.3,
      EffectController(duration: 0.15, alternate: true, repeatCount: 5),
    );

    // Efek Transisi Warna Merah (Damage Flash)
    final colorEffect = ColorEffect(
      Colors.red,
      EffectController(duration: 0.15, alternate: true, repeatCount: 5),
      opacityTo:
          0.3, // Intensitas kemerahan diturunkan ke 30% agar kontrasnya tidak terlalu tajam
    );

    // Efek visual 'Bump' (Motor terpental/membesar sejenak akibat benturan)
    final scaleEffect = ScaleEffect.by(
      Vector2.all(1.15), // Membesar 15% dari ukuran asli
      EffectController(duration: 0.15, alternate: true, repeatCount: 1),
    );

    _damageEffects.addAll([opacityEffect, colorEffect, scaleEffect]);
    for (final effect in _damageEffects) {
      add(effect);
    }
  }

  @override
  void render(Canvas canvas) {
    if (isMagnetActive) {
      // Gambar efek gelombang hisapan magnet (Contracting Waves)
      final int waveCount = 3;
      for (int i = 0; i < waveCount; i++) {
        // wavePhase mengecil dari 1.0 ke 0.0 secara berulang untuk efek menarik ke dalam
        double wavePhase =
            1.0 - ((_magnetWaveTimer * 2.0 + (i / waveCount)) % 1.0);

        double radius = size.x * 0.2 + (size.x * 0.8 * wavePhase);
        int alpha = (180 * wavePhase).toInt().clamp(0, 255);

        _auraPaint.color = Colors.lightBlueAccent.withAlpha(alpha);
        _auraPaint.strokeWidth = 2.0 + (5.0 * wavePhase);

        canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius, _auraPaint);
      }
    }
    if (hasShield) {
      // Gambar lingkaran aura hijau di sekitar motor
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x *
            0.65, // Sedikit lebih besar dari aura magnet agar tidak terlalu bertumpuk
        _shieldAuraPaint,
      );
    }
    super.render(canvas); // Render motor di atas aura
  }
}
