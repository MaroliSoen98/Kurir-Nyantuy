import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class Coin extends SpriteComponent with HasGameRef<KurirGame> {
  double worldX;
  double worldY = -30; // Melayang sedikit di atas jalan
  double worldZ;
  final Vector2 baseSize;
  late final CircleHitbox hitbox;

  Coin({required this.worldX, required this.worldZ, required this.baseSize})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    try {
      sprite = Sprite(
        gameRef.images.fromCache('koin.png'),
      ); // Panggil Instan dari Cache
    } catch (e) {
      // Fallback aman
    }
    paint.filterQuality = FilterQuality.none;

    hitbox = CircleHitbox();
    add(hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gerakkan mendekat ke kamera
    worldZ -= gameRef.gameSpeed * dt;

    // Hapus dari memori jika sudah lewat di belakang layar
    if (worldZ < -100) {
      removeFromParent();
      return;
    }

    // Proyeksi Skala Pseudo-3D
    final scale = gameRef.getScale(worldZ);
    // Gunakan setValues untuk mencegah GC lag
    size.setValues(baseSize.x * 4.0 * scale, baseSize.y * 4.0 * scale);
    position.setValues(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );

    // Sesuaikan radius hitbox agar 70% dari ukuran sprite untuk kolisi yang lebih presisi.
    // Operasi ini sangat ringan dan tidak akan mempengaruhi performa.
    hitbox.radius = (min(size.x, size.y) / 2) * 0.7;
  }
}
