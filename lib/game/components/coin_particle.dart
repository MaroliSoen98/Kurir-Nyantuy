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

  CoinParticle({required super.position});

  @override
  Future<void> onLoad() async {
    particle = Particle.generate(
      count: 10, // Jumlah partikel yang muncul
      lifespan: 0.6, // Durasi partikel ada di layar (dalam detik)
      generator: (i) => AcceleratedParticle(
        acceleration: Vector2(0, 200), // Sedikit efek gravitasi ke bawah
        speed: Vector2(
          _random.nextDouble() * 200 -
              100, // Kecepatan horizontal acak (kiri/kanan)
          _random.nextDouble() * -350, // Semburan awal ke arah atas
        ),
        child: CircleParticle(
          radius: _random.nextDouble() * 2.5 + 1.0, // Ukuran partikel acak
          paint: _particlePaint, // Gunakan paint yang sudah di-cache
        ),
      ),
    );
  }
}
