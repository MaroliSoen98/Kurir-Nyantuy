import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/kurir_game.dart';
import 'game/components/game_over.dart';
import 'game/components/main_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi ke Portrait (9:16 cocok untuk ini)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Mode Fullscreen
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const KurirSantuyApp());
}

class KurirSantuyApp extends StatelessWidget {
  const KurirSantuyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kurir Santuy',
      theme: ThemeData(
        // Nantinya ganti dengan font pixel art retro
        fontFamily: 'Courier',
      ),
      home: Scaffold(
        body: GameWidget(
          game: KurirGame(),
          initialActiveOverlays: const ['MainMenu'],
          overlayBuilderMap: {
            'GameOver': (context, game) =>
                GameOverOverlay(game: game as KurirGame),
            'MainMenu': (context, game) =>
                MainMenuOverlay(game: game as KurirGame),
          },
        ),
      ),
    );
  }
}
