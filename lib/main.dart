import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/kurir_game.dart';
import 'game/components/game_over.dart';
import 'game/components/main_menu.dart';
import 'game/components/loading_overlay.dart';
import 'game/components/pause_menu.dart';

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
        // Mengatur font default aplikasi ke font game yang sudah didaftarkan
        fontFamily: 'LuckiestGuy',
      ),
      home: Scaffold(
        body: GameWidget(
          game: KurirGame(),
          // Builder ini akan menampilkan layar pemuatan kustom selama game
          // mempersiapkan semua aset di latar belakang (saat `onLoad` berjalan).
          loadingBuilder: (context) => Material(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ganti ikon loading putar dengan gambar PNG kustom Anda
                  Image.asset(
                    'assets/images/loading_icon.png', // Pastikan path ini benar
                    width: 150,
                    height: 150,
                    // Fallback jika gambar tidak ditemukan, kembali ke ikon putar.
                    errorBuilder: (context, error, stackTrace) =>
                        const CircularProgressIndicator(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'LOADING...',
                    style: TextStyle(
                      fontSize: 36, // Ukuran lebih besar agar menonjol
                      color: Colors.white,
                      letterSpacing: 2.0, // Sedikit jarak antar huruf
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tambahkan loading bar horizontal di bawah teks
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          initialActiveOverlays: const ['MainMenu'],
          overlayBuilderMap: {
            'GameOver': (context, game) =>
                GameOverOverlay(game: game as KurirGame),
            'MainMenu': (context, game) =>
                MainMenuOverlay(game: game as KurirGame),
            'Loading': (context, game) =>
                const LoadingOverlay(), // Daftarkan overlay baru di sini
            'PauseMenu': (context, game) =>
                PauseMenuOverlay(game: game as KurirGame),
            // Tambahkan Tombol Mengapung ala Retro di Tengah Atas
            'PauseButton': (context, game) => SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => (game as KurirGame).pauseGame(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF2A6D,
                          ), // Warna khas neon menu
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF1A1A1A),
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.pause,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}
