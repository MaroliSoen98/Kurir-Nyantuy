import 'package:flutter/material.dart';
import '../kurir_game.dart';

class GameOverOverlay extends StatelessWidget {
  final KurirGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2D1B4E), // Deep Indigo
            border: Border.all(
              color: Colors.white,
              width: 6,
            ), // Pixel Art Style
            borderRadius: BorderRadius.zero, // Sudut kaku tajam
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF1A1A1A),
                blurRadius: 0,
                offset: Offset(8, 8), // Heavy block shadow
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Meme Title
              Container(
                transform: Matrix4.rotationZ(-0.05),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3366), // Soft Pinkish Red
                  border: Border.all(color: Colors.black, width: 4),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Text(
                  'YAH NUBRUK 😭',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SKOR LU LUMAYAN BRO:',
                style: TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Animasi hitung untuk skor jarak
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: game.distanceTravelled),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    '${value.toInt()} M',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              // Coin Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: Colors.yellowAccent, width: 4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 24)),
                    // Animasi hitung untuk perolehan koin
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: game.currentCoins.toDouble(),
                      ),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '+${value.toInt()} CUAN',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Giant Retry Button
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF39FF14), // Hijau Nyala
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: const ContinuousRectangleBorder(
                      // Kotak Arcade
                      side: BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  onPressed: () {
                    game.overlays.remove('GameOver');
                    game.resetGame();
                    game.startGame();
                  },
                  child: const Text(
                    'COBA LAGI BANG JAGO! 🔄',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Back to Main Menu Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellowAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: const ContinuousRectangleBorder(
                      // Kotak Arcade
                      side: BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  onPressed: () {
                    game.overlays.remove('GameOver');
                    game.isMainMenu =
                        true; // Aktifkan kembali mode live background
                    game.resetGame(); // Reset semua data permainan
                    game.resumeEngine(); // Jalankan lagi game loop untuk animasi
                    game.overlays.add('MainMenu');
                  },
                  child: const Text(
                    'BALIK TONGKRONGAN 🏠',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
