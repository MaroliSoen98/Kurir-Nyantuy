import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class Puddle extends PositionComponent with HasGameRef<KurirGame> {
  double worldX;
  double worldY =
      -5; // Sedikit di atas aspal agar tidak z-fighting dengan tekstur aspal
  double worldZ;
  final Vector2 baseSize;
  Sprite? sprite;
  bool hasSplashed = false; // Penanda agar cipratan tidak spam terus-menerus

  // Cat untuk fallback oval biru genangan air
  final Paint paint = Paint()..color = const Color(0xFF4A90E2).withOpacity(0.4);

  Puddle({required this.worldX, required this.worldZ, required this.baseSize})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      // Akan menggunakan puddle.png jika kamu sudah memasukkannya ke folder assets
      sprite = Sprite(gameRef.images.fromCache('puddle.png'));
    } catch (e) {
      // Jika gambar belum ada, otomatis akan menggunakan oval biru di render()
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

    // Pengecekan overlap dihapus dari sini karena sudah ditangani secara aman
    // dan cerdas saat proses Spawn di kurir_game.dart!

    final scale = gameRef.getScale(worldZ);
    size.setValues(baseSize.x * scale, baseSize.y * scale);
    position.setValues(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      // Fallback genangan air (Oval)
      canvas.drawOval(size.toRect(), paint);
    }
  }
}
