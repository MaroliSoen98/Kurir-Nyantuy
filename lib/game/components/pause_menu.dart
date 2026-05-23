import 'package:flutter/material.dart';
import '../kurir_game.dart';

class PauseMenuOverlay extends StatelessWidget {
  final KurirGame game;

  const PauseMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors
          .black54, // Latar belakang semi-transparan yang menggelapkan game
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A35), // Biru dongker gelap khas Retro RPG
            border: Border.all(
              color: Colors.white,
              width: 4,
            ), // Ketebalan ala Pixel Art
            borderRadius: BorderRadius.zero, // Sudut tajam kaku
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF111111),
                blurRadius: 0,
                offset: Offset(6, 6), // Hard shadow khas retro arcade
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Judul Pause
              const Text(
                'PAUSE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFFFD700), // Kuning Emas Cerah
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'GAME DIJEDA',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // Tombol Lanjut (Resume)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF), // Cyan retro
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero, // Kotak tajam pixel art
                      side: BorderSide(color: Colors.white, width: 3),
                    ),
                  ),
                  onPressed: () {
                    game.resumeGame();
                  },
                  child: const Text(
                    'LANJUT MAIN',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tombol Main Menu (Quit)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2A6D), // Pink retro
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(color: Colors.white, width: 3),
                    ),
                  ),
                  onPressed: () {
                    game.resumeGame(); // Hapus overlay pause
                    game.overlays.remove(
                      'PauseButton',
                    ); // Hilangkan tombol pause
                    game.resetGame(); // Reset data game
                    game.overlays.add('MainMenu'); // Tampilkan main menu
                    game.pauseEngine(); // Hentikan game kembali ke state awal
                  },
                  child: const Text(
                    'KEMBALI KE MENU',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 0,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
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
