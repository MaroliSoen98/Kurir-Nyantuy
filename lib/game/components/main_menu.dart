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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Top-Left Settings Button
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () {
                    // TODO: Aksi ketika tombol setting ditekan
                  },
                  child: SizedBox(
                    width: 48, // Sesuaikan ukurannya agar pas
                    height: 48,
                    child: Image.asset(
                      'assets/images/btn_setting.png', // Sesuaikan nama file gambar tombol setting kamu
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  // 1. TOP SECTION: Game Title
                  Image.asset(
                    'assets/images/logo.png', // Sesuaikan dengan nama file gambar logo kamu
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),

                  // 2. MAIN CENTER STACK: A. High Score Panel
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40.0,
                    ), // Padding untuk mengecilkan gambar panel highscore
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Image.asset(
                            'assets/images/panel_highscore.png', // Sesuaikan nama file gambar panel kamu
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                        // Menempatkan teks skor di atas gambar panel (di sisi kanan)
                        Padding(
                          padding: const EdgeInsets.only(
                            right:
                                50.0, // Disesuaikan ulang karena gambarnya mengecil
                            top:
                                50.0, // Disesuaikan ulang karena gambarnya mengecil
                          ),
                          child: Text(
                            '${game.bestDistance.toInt()} M',
                            style: const TextStyle(
                              fontFamily: 'PixelFont', // Font Retro Pixel
                              fontSize:
                                  20, // Ukuran teks dikecilkan agar seimbang dengan panel
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 6), // Very small gap
                  // 3. MAIN CENTER STACK: B. Main Play Button
                  GestureDetector(
                    onTap: () {
                      game.overlays.remove('MainMenu');
                      game.startGame();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 70.0,
                      ), // Padding diperbesar lagi agar ukuran tombol GASPOL benar-benar mengecil dan sesuai
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.asset(
                          'assets/images/btn_play.png', // Sesuaikan dengan nama file gambar tombol kamu
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ), // Jarak diatur ulang agar tidak terlalu dempet setelah dikecilkan
                  // 4. MAIN CENTER STACK: C. Secondary Button
                  GestureDetector(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 70.0,
                      ), // Samakan padding dengan tombol GASPOL MANG agar ukurannya persis sama
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.asset(
                          'assets/images/btn_bengkel.png', // Sesuaikan dengan nama file gambar tombol kamu
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 140,
                  ), // Angka ini diperbesar untuk mendorong 3 tombol bawah agar lebih turun
                  // 5. BOTTOM NAVIGATION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                          ), // Ruang jarak antar tombol
                          child: GestureDetector(
                            onTap: () {},
                            child: SizedBox(
                              height: 60,
                              child: Image.asset(
                                'assets/images/btn_shop.png', // Sesuaikan nama file gambar tombol kamu
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: GestureDetector(
                            onTap: () {},
                            child: SizedBox(
                              height: 60,
                              child: Image.asset(
                                'assets/images/btn_mission.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: GestureDetector(
                            onTap: () {},
                            child: SizedBox(
                              height: 60,
                              child: Image.asset(
                                'assets/images/btn_achieves.png', // Sesuaikan nama file gambar tombol kamu
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
