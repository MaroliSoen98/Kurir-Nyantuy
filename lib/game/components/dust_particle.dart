import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Komponen ini menciptakan efek kepulan debu/asap saat motor nunduk (sliding)
class DustParticle extends ParticleSystemComponent {
  static final Random _random = Random();
  // Warna abu-abu/putih semi-transparan untuk efek asap
  static final Paint _particlePaint = Paint()..color = const Color(0x77FFFFFF);

  DustParticle({required super.position})
    : super(
        particle: Particle.generate(
          count: 5, // Jumlah kepulan debu per tembakan
          lifespan: 0.4, // Cepat menghilang agar tidak menumpuk
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, -150), // Asap perlahan naik ke udara
            speed: Vector2(
              _random.nextDouble() * 150 - 75, // Menyebar ke kiri dan kanan
              _random.nextDouble() * -100, // Kecepatan lemparan ke atas
            ),
            child: CircleParticle(
              radius:
                  _random.nextDouble() * 4.0 +
                  2.0, // Ukuran kepulan debu bervariasi
              paint: _particlePaint,
            ),
          ),
        ),
      );
}
