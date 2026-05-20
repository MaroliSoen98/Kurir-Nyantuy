import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../kurir_game.dart';
import 'obstacle.dart';
import 'coin.dart';

class Player extends SpriteComponent
    with HasGameRef<KurirGame>, CollisionCallbacks {
  // -1: Kiri, 0: Tengah, 1: Kanan
  int currentLane = 0;
  double laneSpacing = 180.0;

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

  bool hasShield = false; // Status Shield/Booster Aktif
  bool isInvincible = false;
  double invincibilityTimer = 0;

  final Vector2 baseSize = Vector2(
    110,
    150,
  ); // Diperbesar agar proporsional di lajur

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
      sprite = Sprite(gameRef.images.fromCache('motor.png'));
    } catch (e) {
      debugPrint("Sprite motor.png tidak ditemukan di cache.");
    }
    paint.filterQuality = FilterQuality.none; // Mencegah pixel art menjadi blur

    // Tambahkan Hitbox untuk deteksi tabrakan
    add(RectangleHitbox());
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

    // Lerp transisi pindah lane (Smoothed movement) - Diperlambat dari 15 ke 10 agar lebih natural
    worldX += dx * 10 * dt;

    // Efek Motion Animasi Belok (Miring/Lean) - Maksimal miring ~15 derajat (0.25 radian)
    angle = (dx * 0.003).clamp(-0.25, 0.25);

    // Logika Nunduk
    if (isSliding) {
      slideTimer -= dt;
      if (slideTimer <= 0) {
        isSliding = false; // Kembali berdiri
      }
    }

    // Logika Kebal Sesaat (Invincibility)
    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
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
    size = baseSize * scale;

    // Secara visual membuat motor & kurir memendek saat nunduk
    if (isSliding) {
      size.y = (baseSize.y * 0.5) * scale;
    }

    position = Vector2(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (isInvincible) return; // Jika kebal, abaikan semua tabrakan

    // Jika menabrak rintangan, panggil fungsi gameOver
    if (other is Obstacle) {
      // Cek overlap kedalaman ruang 3D (Z)
      if ((worldZ - other.worldZ).abs() < 80.0) {
        bool isHit = false;

        if (other.isFloating) {
          // Nabrak portal: Jika tidak nunduk, atau malah lompat menyundul
          if (!isSliding || worldY < -20.0) {
            isHit = true;
          }
        } else {
          // Nabrak rintangan bawah: Jika lompatan kurang tinggi
          if (worldY > (other.isSmall ? -40.0 : -60.0)) {
            isHit = true;
          }
        }

        if (isHit) {
          if (other.isRemoving) {
            return; // Mencegah fungsi terpanggil berkali-kali
          }
          if (hasShield) {
            hasShield = false;
            other.removeFromParent(); // Hancurkan obstacle
            _triggerShake();
          } else {
            _triggerShake();
            gameRef.playerHit();
          }
        }
      }
    } else if (other is Coin) {
      // Perbesar batas deteksi Z (150.0) agar koin langsung diambil saat menyentuh moncong depan motor
      if ((worldZ - other.worldZ).abs() < 150.0 && worldY > -60.0) {
        if (other.isRemoving) return; // Mencegah koin ganda
        gameRef.currentCoins++;
        other.removeFromParent();
      }
    }
  }

  void _triggerShake() {
    // Simulasi Screen/Player hit feedback ringan (Screen Shake)
    add(
      MoveEffect.by(
        Vector2(15, 0),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3),
      ),
    );
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
}
