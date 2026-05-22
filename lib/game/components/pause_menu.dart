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
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF5E3A),
                Color(0xFFFF2A6D),
              ], // Warm Sunset Gradient (Sama dengan Main Menu)
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white,
              width: 6,
            ), // Ketebalan ala Pixel Art
            borderRadius: BorderRadius.zero, // Sudut tajam kaku
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF1A1A1A),
                blurRadius: 0,
                offset: Offset(8, 8), // Hard shadow khas retro arcade
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
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0xFF2D1B4E),
                      blurRadius: 2,
                      offset: Offset(8, 8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'TARIK NAFAS DULU NGAB! ☕',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellowAccent,
                ),
              ),
              const SizedBox(height: 36),
              // Tombol Lanjut (Resume)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF39FF14), // Hijau Nyala
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: const ContinuousRectangleBorder(
                      side: BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  onPressed: () {
                    game.resumeGame();
                  },
                  child: const Text(
                    'LANJUT GAS! 🚀',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
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
                    backgroundColor: const Color(0xFF00E5FF), // Cyan cerah
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: const ContinuousRectangleBorder(
                      side: BorderSide(color: Colors.black, width: 4),
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
                    'BALIK KANDANG 🏠',
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
