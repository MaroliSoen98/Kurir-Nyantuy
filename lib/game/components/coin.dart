import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class Coin extends PositionComponent with HasGameRef<KurirGame> {
  double worldX;
  double worldY = -30; // Melayang sedikit di atas jalan
  double worldZ;
  final Vector2 baseSize;
  Sprite? sprite;
  final Paint paint = Paint();

  Coin({required this.worldX, required this.worldZ, required this.baseSize})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    try {
      sprite = Sprite(gameRef.images.fromCache('koin.png'));
    } catch (e) {
      // Fallback
    }
    paint.filterQuality = FilterQuality.none; // Anti-blur untuk Pixel Art
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

    size.setValues(
      baseSize.x * 3.0 * scale, // Diperbesar 3x lipat agar sangat jelas
      baseSize.y * 3.0 * scale, // Diperbesar 3x lipat agar sangat jelas
    );

    position.setValues(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      sprite!.render(canvas, size: size, overridePaint: paint);
    } else {
      // Asset sementara berupa lingkaran emas jika gambar tidak ada
      canvas.drawOval(size.toRect(), Paint()..color = const Color(0xFFFFD700));
    }
  }
}
