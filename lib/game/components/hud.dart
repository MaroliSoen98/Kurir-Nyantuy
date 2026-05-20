import 'package:kurir_santuy/game/kurir_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class HudComponent extends PositionComponent with HasGameRef<KurirGame> {
  late TextComponent distanceText;
  late TextComponent coinText;
  late TextComponent livesText;

  @override
  Future<void> onLoad() async {
    // Style Text Ala Retro Arcade / Hypercasual
    final distanceStyle = TextPaint(
      style: const TextStyle(
        fontSize: 36,
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 2,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(2, 2)),
        ],
      ),
    );
    final coinStyle = TextPaint(
      style: const TextStyle(
        fontSize: 32,
        color: Colors.yellowAccent,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(2, 2)),
        ],
      ),
    );

    final livesStyle = TextPaint(
      style: const TextStyle(
        fontSize: 32,
        color: Colors.white,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Colors.red, blurRadius: 0, offset: Offset(2, 2)),
          Shadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
    );

    distanceText = TextComponent(
      text: '0 M',
      position: Vector2(20, 50),
      textRenderer: distanceStyle,
    );

    coinText = TextComponent(
      text: '🪙 0',
      position: Vector2(20, 100),
      textRenderer: coinStyle,
    );

    livesText = TextComponent(
      text: '❤️ x3',
      position: Vector2(gameRef.size.x - 20, 100),
      anchor: Anchor.topRight,
      textRenderer: livesStyle,
    );

    addAll([distanceText, coinText, livesText]);
  }

  @override
  void update(double dt) {
    distanceText.text = '${gameRef.distanceTravelled.toInt()} M';
    coinText.text = '🪙 ${gameRef.currentCoins}';
    livesText.text = '❤️ x${(gameRef as KurirGame).playerLives}';
  }
}
