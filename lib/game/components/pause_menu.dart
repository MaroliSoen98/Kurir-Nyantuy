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
          decoration: const BoxDecoration(
            image: DecorationImage(
              // TODO: Sesuaikan nama file gambar aset kotak background pause kamu!
              image: AssetImage('assets/images/panel_pause.png'),
              fit: BoxFit.fill, // Memaksa gambar melebar penuh mengisi kotak
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Judul Pause Utama (SEBENTAR BRO)
              Image.asset(
                // TODO: Sesuaikan dengan nama file gambar aset 'Sebentar Bro'
                'assets/images/title_sebentar.png',
                height: 90, // Ukuran diperbesar lagi
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12), // Jarak antara kedua teks
              // Sub Judul Pause (NGASO DULU)
              Image.asset(
                // TODO: Sesuaikan dengan nama file gambar aset 'Ngaso Dulu'
                'assets/images/title_ngaso.png',
                height: 20, // Ukuran dikecilkan lagi
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 36),
              // Tombol Lanjut (Resume)
              GestureDetector(
                onTap: () {
                  game.resumeGame();
                },
                child: Container(
                  width: double.infinity,
                  height:
                      70, // Tinggi tombol bisa kamu sesuaikan biar pas sama gambar
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      // TODO: Ganti dengan nama file gambar aset tombol kamu!
                      image: AssetImage('assets/images/btn_lanjut.png'),
                      fit: BoxFit.fill,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'YOK LANJUT',
                    style: TextStyle(
                      fontFamily: 'PixelFont',
                      fontSize: 30, // Sedikit dibesarkan biar makin jelas
                      fontWeight: FontWeight.w900,
                      color: Colors
                          .black, // Ubah warna teksnya kalau tabrakan sama warna gambarmu
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tombol Main Menu (Quit)
              GestureDetector(
                onTap: () {
                  game.resumeGame(); // Hapus overlay pause
                  game.overlays.remove('PauseButton'); // Hilangkan tombol pause
                  game.isMainMenu =
                      true; // Aktifkan mode live background kembali
                  game.resetGame(); // Reset data game
                  game.overlays.add('MainMenu'); // Tampilkan main menu
                },
                child: Container(
                  width: double.infinity,
                  height: 70, // Sama persis dengan tombol "YOK LANJUT" di atas
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      // TODO: Ganti dengan nama file gambar aset tombol 'Main Menu' milikmu
                      image: AssetImage('assets/images/btn_menu.png'),
                      fit: BoxFit.fill,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'BALIK MENU', // Teks aku persingkat, hapus aja kalau gambarmu udah ada teksnya
                    style: TextStyle(
                      fontFamily: 'PixelFont',
                      fontSize: 30, // Sama dengan tombol di atas
                      fontWeight: FontWeight.w900,
                      color: Colors
                          .black, // Sesuaikan warna bila menabrak warna gambarmu
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
