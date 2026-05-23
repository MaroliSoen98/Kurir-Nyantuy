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
  double shakeTimer = 0; // Timer untuk efek goncangan tanpa membebani posisi 3D

  bool hasShield = false; // Status Shield/Booster Aktif
  bool isInvincible = false;
  double invincibilityTimer = 0;

  // Status Power Up Magnet
  bool isMagnetActive = false;
  double magnetDuration = 0;

  final Vector2 baseSize = Vector2(
    110,
    150,
  ); // Diperbesar agar proporsional di lajur

  // Variabel untuk menyimpan sprite yang sudah di-load agar bisa diganti-ganti
  Sprite? _spriteNormal;
  Sprite? _spriteNunduk;

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
      sprite = _spriteNormal; // Atur sprite awal ke kondisi normal
    } catch (e) {
      debugPrint("Sprite motor tidak ditemukan di cache: $e");
    }
    paint.filterQuality = FilterQuality.none; // Mencegah pixel art menjadi blur
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

    final activeChildren = gameRef.children
        .toList(); // Ambil snapshot daftar objek sekali saja (Anti-Crash CME!)

    // Logika Nunduk
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

    // Logika Kebal Sesaat (Invincibility)
    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
      }
    }

    // Logika Power Up Magnet (Hisap Koin)
    if (isMagnetActive) {
      magnetDuration -= dt;
      if (magnetDuration <= 0) {
        isMagnetActive = false;
      } else {
        // Telusuri koin-koin dan hisap mereka jika jaraknya masuk jangkauan
        for (final child in activeChildren) {
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

    // --- LOGIKA TABRAKAN 3D MANUAL (SUPER RINGAN & 0 DELAY) ---
    // Menggantikan 100% sistem deteksi Quadtree Flame yang sangat membebani HP
    for (final child in activeChildren) {
      if (child is Obstacle) {
        if (isInvincible || child.isRemoving) continue; // Abaikan jika kebal

        final obstacle = child;

        // 1. Cek Sumbu Z (Kedalaman / Depan-Belakang)
        bool inZRange =
            worldZ >= (obstacle.worldZ - 80.0) &&
            worldZ <= (obstacle.worldZ + obstacle.depthZ + 80.0);
        if (!inZRange) continue;

        // 2. Cek Sumbu X (Lajur Kiri/Tengah/Kanan)
        double obstacleWidth = obstacle.baseSize.x * 0.9;
        double obstacleLeft = obstacle.worldX - (obstacleWidth / 2);
        double obstacleRight = obstacle.worldX + (obstacleWidth / 2);

        double playerWidth = baseSize.x * 0.5;
        double playerLeft = worldX - (playerWidth / 2);
        double playerRight = worldX + (playerWidth / 2);

        bool inXRange =
            playerRight > obstacleLeft && playerLeft < obstacleRight;
        if (!inXRange) continue;

        // 3. Cek Sumbu Y (Ketinggian / Lompat / Nunduk)
        bool isHit = false;
        if (obstacle.isFloating) {
          // PORTAL: Wajib nunduk. Lompat atau diam = nabrak
          isHit = isJumping || !isSliding;
        } else {
          if (obstacle.isSmall) {
            // GALIAN: Pemain harus melompat cukup tinggi untuk melewatinya
            isHit = worldY > -30.0;
          } else {
            // RINTANGAN NORMAL (Emak-emak & Tembok):
            // Bisa dilompati asalkan pemain sedang melompat cukup tinggi!
            isHit = worldY > -60.0;
          }
        }

        // 4. Eksekusi Damage
        if (isHit) {
          if (hasShield) {
            hasShield = false;
            obstacle.removeFromParent();
            _triggerShake();
          } else {
            _triggerShake();
            gameRef.playerHit();
          }
          break; // Stop loop jika sudah terkena hit
        }
      } else if (child is Coin) {
        if (child.isRemoving) continue;

        // Jarak deteksi matematika murni 3D Koin (Jauh lebih ringan dari mengecek Hitbox Polygon)
        if ((worldZ - child.worldZ).abs() < 150.0 &&
            (worldX - child.worldX).abs() < 90.0 &&
            (worldY - child.worldY).abs() < 80.0) {
          gameRef.currentCoins++;
          gameRef.add(CoinParticle(position: child.position));
          child.removeFromParent();
        }
      } else if (child is Magnet) {
        if (child.isRemoving) continue;

        if ((worldZ - child.worldZ).abs() < 150.0 &&
            (worldX - child.worldX).abs() < 90.0 &&
            (worldY - child.worldY).abs() < 80.0) {
          isMagnetActive = true;
          magnetDuration = 10.0; // Aktif selama 10 detik penuh
          child.removeFromParent();
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

    // Efek Kedip-kedip (Blinking)
    add(
      OpacityEffect.to(
        0.3,
        EffectController(duration: 0.15, alternate: true, repeatCount: 5),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    if (isMagnetActive) {
      // Gambar lingkaran aura magnet biru di sekitar motor
      final auraPaint = Paint()
        ..color = Colors.lightBlueAccent.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0;
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.6,
        auraPaint,
      );
    }
    super.render(canvas); // Render motor di atas aura
  }
}
