import 'package:flutter/material.dart';
import '../kurir_game.dart';

class MainMenuOverlay extends StatelessWidget {
  final KurirGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF5E3A),
                Color(0xFFFF2A6D),
              ], // Warm Sunset Gradient
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
              // Stiker Peringatan Miring
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent,
                    border: Border.all(color: Colors.black, width: 4),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Text(
                    'AWAS EMAK-EMAK! 🛵💨',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Judul Game Heboh
              const Text(
                'KURIR\nSANTUY',
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
              const SizedBox(height: 20),
              // Kartu Rekor High Score
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 4),
                  borderRadius: BorderRadius.zero,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'REKOR NGEBUT TEROOOS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${game.bestDistance.toInt()} M',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Tombol Play Raksasa
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF39FF14,
                    ), // Hijau Nyala yang lebih soft
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: const ContinuousRectangleBorder(
                      // Bentuk kaku Pixel Art
                      side: BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  onPressed: () {
                    game.overlays.remove('MainMenu');
                    game.startGame(); // Mulai jalankan game beserta BGM
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'GASPOL MANG! ',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 0,
                              offset: Offset(4, 4), // Bayangan tajam pixel art
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '🚀',
                        style: TextStyle(
                          fontSize: 28,
                        ), // Emoji polos tanpa shadow
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tombol Shop
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF), // Cyan cerah
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const ContinuousRectangleBorder(
                      // Bentuk kaku Pixel Art
                      side: BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  onPressed: () {
                    // TODO: Ke menu Shop
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BENGKEL MANG OLEH ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 0,
                              offset: Offset(3, 3), // Bayangan kaku
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '🛠️',
                        style: TextStyle(
                          fontSize: 20,
                        ), // Emoji polos tanpa shadow
                      ),
                    ],
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
