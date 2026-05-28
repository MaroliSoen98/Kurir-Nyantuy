import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';

/// Komponen ini menciptakan efek koin tumpah berserakan saat pemain menabrak rintangan
class SpilledCoinParticle extends ParticleSystemComponent {
  static final Random _random = Random();

  SpilledCoinParticle({
    required super.position,
    required Sprite sprite,
    int amount = 10,
  }) : super(
         particle: Particle.generate(
           count: amount,
           lifespan: 1.2, // Tahan sedikit lebih lama saat jatuh
           generator: (i) {
             final size =
                 _random.nextDouble() * 15.0 +
                 15.0; // Ukuran koin acak agar variatif
             return AcceleratedParticle(
               acceleration: Vector2(
                 0,
                 600,
               ), // Gravitasi menarik jatuh ke bawah
               speed: Vector2(
                 _random.nextDouble() * 500 -
                     250, // Meledak (menyebar) ke kiri dan kanan
                 _random.nextDouble() * -500 - 150, // Terpental kuat ke atas
               ),
               child: SpriteParticle(
                 sprite: sprite, // Menggunakan aset gambar koin langsung
                 size: Vector2.all(size),
               ),
             );
           },
         ),
       );
}
