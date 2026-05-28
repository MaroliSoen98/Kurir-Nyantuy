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
          // Margin dan padding kiri-kanan dikurangi agar box dan tombol di dalamnya bisa membentang lebih lebar
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
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
                    fontFamily: 'PixelFont',
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12), // Jarak ke skor diperkecil
              const Text(
                'SKOR LU LUMAYAN BRO:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PixelFont',
                  color: Colors.yellowAccent,
                  fontSize: 26,
                  height: 1.1, // Memotong padding/jarak bawaan font pixel
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(2, 2),
                    ),
                  ],
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
                      fontFamily: 'PixelFont',
                      color: Colors.white,
                      fontSize: 74,
                      height: 1.0, // Memotong padding/jarak bawaan font pixel
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
              const SizedBox(
                height: 4,
              ), // Jarak dari teks skor M ke kotak koin diperkecil
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
                    const Text(
                      '🪙 ',
                      style: TextStyle(fontFamily: 'PixelFont', fontSize: 24),
                    ),
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
                            fontFamily: 'PixelFont',
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
              const SizedBox(
                height: 16,
              ), // Jarak dari kotak koin ke tombol diperkecil
              // Giant Retry Button (Box Hijau diganti Asset)
              GestureDetector(
                onTap: () {
                  game.overlays.remove('GameOver');
                  game.resetGame();
                  game.startGame();
                },
                child: Container(
                  width: double.infinity,
                  height: 110, // Tinggi diperbesar secara signifikan
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      // TODO: Sesuaikan nama file gambar aset kotak hijau kamu!
                      image: AssetImage('assets/images/btn_retry.png'),
                      fit: BoxFit
                          .fill, // Memaksa gambar melebar penuh ke samping seperti tombol Flutter
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'COBA LAGI BANG JAGO!',
                    style: TextStyle(
                      fontFamily: 'PixelFont',
                      color: Colors.black, // Warna teks hitam manual
                      fontSize:
                          34, // Teks dibesarkan sedikit menyesuaikan tombol baru
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 4,
              ), // Jarak antara kedua tombol diperpendek
              // Back to Main Menu Button (Box Kuning diganti Asset)
              GestureDetector(
                onTap: () {
                  game.overlays.remove('GameOver');
                  game.isMainMenu =
                      true; // Aktifkan kembali mode live background
                  game.resetGame(); // Reset semua data permainan
                  game.resumeEngine(); // Jalankan lagi game loop untuk animasi
                  game.overlays.add('MainMenu');
                },
                child: Container(
                  width: double.infinity,
                  height: 85, // Tinggi diperbesar secara signifikan
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      // TODO: Sesuaikan nama file gambar aset kotak kuning kamu!
                      image: AssetImage('assets/images/btn_home.png'),
                      fit: BoxFit
                          .fill, // Memaksa gambar melebar penuh ke samping seperti tombol Flutter
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'BALIK TONGKRONGAN',
                    style: TextStyle(
                      fontFamily: 'PixelFont',
                      color: Colors.black, // Warna teks hitam manual
                      fontSize: 28, // Teks disesuaikan
                      fontWeight: FontWeight.w900,
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
