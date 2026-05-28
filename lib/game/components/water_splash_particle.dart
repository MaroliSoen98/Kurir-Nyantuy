import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Komponen ini menciptakan efek cipratan air saat ban motor mengenai genangan
class WaterSplashParticle extends ParticleSystemComponent {
  static final Random _random = Random();
  // Warna biru transparan untuk tetesan air
  static final Paint _waterPaint = Paint()..color = const Color(0xAA4A90E2);

  WaterSplashParticle({required super.position})
    : super(
        particle: Particle.generate(
          count: 14, // Jumlah tetesan cipratan
          lifespan: 0.35, // Cepat menghilang setelah memuncrat
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, 600), // Gravitasi menarik jatuh ke bawah
            speed: Vector2(
              _random.nextDouble() * 300 -
                  150, // Memuncrat menyebar ke kiri & kanan ban
              _random.nextDouble() * -200 - 50, // Terlempar ke atas
            ),
            child: CircleParticle(
              radius:
                  _random.nextDouble() * 3.0 +
                  1.5, // Ukuran rintik air bervariasi
              paint: _waterPaint,
            ),
          ),
        ),
      );
}
