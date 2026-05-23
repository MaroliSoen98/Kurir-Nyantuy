import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Komponen ini menciptakan efek ledakan partikel kecil berwarna kuning
/// saat koin berhasil diambil oleh pemain.
class CoinParticle extends ParticleSystemComponent {
  // Gunakan satu instance Random untuk semua partikel (Optimasi Performa)
  static final Random _random = Random();

  // Simpan Paint object agar tidak dibuat berulang kali (Optimasi Performa)
  static final Paint _particlePaint = Paint()..color = const Color(0xFFFFD700);

  CoinParticle({required super.position})
    : super(
        // Setup partikel sinkron/langsung di konstruktor
        // Mencegah error Null Check dari internal Flame Engine!
        particle: Particle.generate(
          count: 10,
          lifespan: 0.6,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, 200),
            speed: Vector2(
              _random.nextDouble() * 200 - 100,
              _random.nextDouble() * -350,
            ),
            child: CircleParticle(
              radius: _random.nextDouble() * 2.5 + 1.0,
              paint: _particlePaint,
            ),
          ),
        ),
      );
}
