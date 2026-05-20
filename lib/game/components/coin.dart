import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class Coin extends SpriteComponent with HasGameRef<KurirGame> {
  double worldX;
  double worldY = -30; // Melayang sedikit di atas jalan
  double worldZ;
  final Vector2 baseSize;

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

    add(RectangleHitbox());
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
    size = baseSize * scale;
    position = Vector2(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }
}
