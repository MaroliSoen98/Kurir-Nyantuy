import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class Magnet extends PositionComponent with HasGameRef<KurirGame> {
  double worldX;
  double worldY = -40; // Melayang sedikit di atas tanah setara koin
  double worldZ;
  final Vector2 baseSize;
  Sprite? sprite;
  final Paint paint = Paint();

  Magnet({required this.worldX, required this.worldZ, required this.baseSize})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    try {
      sprite = Sprite(gameRef.images.fromCache('magnet.png'));
    } catch (e) {
      // Fallback
    }
    paint.filterQuality = FilterQuality.none;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gerakkan mendekat ke kamera
    worldZ -= gameRef.gameSpeed * dt;

    if (worldZ < -100) {
      removeFromParent();
      return;
    }

    final scale = gameRef.getScale(worldZ);
    size.setValues(
      baseSize.x * 4.0 * scale,
      baseSize.y * 4.0 * scale,
    ); // Scale serupa dengan koin
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
      canvas.drawRect(size.toRect(), Paint()..color = Colors.redAccent);
    }
  }
}
