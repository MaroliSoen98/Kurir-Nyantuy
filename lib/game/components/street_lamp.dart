import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class StreetLamp extends PositionComponent with HasGameRef<KurirGame> {
  double worldX = 0;
  double worldY = 0;
  double worldZ;
  final bool isLeft;
  Sprite? sprite;
  final Paint paint = Paint()..filterQuality = FilterQuality.none;

  StreetLamp({required this.isLeft, required this.worldZ})
    : super(anchor: Anchor.bottomCenter) {
    // Posisikan di pinggir luar bahu jalan (kiri/kanan)
    worldX = isLeft ? -330.0 : 330.0;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      String img = isLeft ? 'lampu_jalan_kiri.png' : 'lampu_jalan_kanan.png';
      sprite = Sprite(gameRef.images.fromCache(img));
    } catch (e) {
      // Fallback diam jika gambar belum ada di cache
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    worldZ -= gameRef.gameSpeed * dt;

    if (worldZ < -200) {
      removeFromParent();
      return;
    }

    final scale = gameRef.getScale(worldZ);
    final w = 180.0 * scale; // Lebar proporsional tiang lampu
    final h = 360.0 * scale; // Tinggi proporsional

    size.setValues(w, h);
    position.setValues(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      sprite!.render(canvas, size: size, overridePaint: paint);
    }
  }
}
