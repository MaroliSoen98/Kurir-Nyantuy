import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Komponen ini menciptakan efek ledakan partikel kecil berwarna kuning
/// saat koin berhasil diambil oleh pemain.
class CoinParticle extends ParticleSystemComponent {
  // Gunakan satu instance Random untuk semua partikel (Optimasi Performa)
  static final Random _random = Random();

  // Warna percikan cahaya kuning keputihan terang
  static final Paint _sparklePaint = Paint()..color = const Color(0xFFFFFF99);

  CoinParticle({required super.position, required Sprite sprite})
    : super(
        particle: Particle.generate(
          count: 6, // 1 koin utama + 5 percikan cahaya
          lifespan: 0.4, // Cepat dan snappy
          generator: (i) {
            if (i == 0) {
              // Partikel Utama: Koin melayang lurus ke atas
              return MovingParticle(
                from: Vector2.zero(),
                to: Vector2(0, -80), // Melayang naik sejauh 80 pixel
                child: SpriteParticle(
                  sprite: sprite,
                  size: Vector2.all(35), // Agak mengecil dari ukuran asli
                ),
              );
            } else {
              // Partikel Sisa: Bintang / Sparkle kecil menyebar
              return AcceleratedParticle(
                speed: Vector2(
                  _random.nextDouble() * 200 - 100,
                  _random.nextDouble() * -200 - 50,
                ),
                child: CircleParticle(
                  radius: _random.nextDouble() * 2.5 + 1.0,
                  paint: _sparklePaint,
                ),
              );
            }
          },
        ),
      );
}
