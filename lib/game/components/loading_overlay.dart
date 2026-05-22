import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Ganti ikon loading putar dengan gambar PNG kustom Anda
            Image.asset(
              'assets/images/loading_icon.png', // Pastikan path ini benar
              width: 150,
              height: 150,
              // Fallback jika gambar tidak ditemukan, menampilkan ikon lari.
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_run,
                color: Colors.white,
                size: 100,
              ),
            ),
            const SizedBox(height: 24),
            // 2. Teks loading
            Text(
              'GETTING READY...', // Teks bisa diubah agar lebih menarik
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 36,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 24),
            // 3. Tambahkan loading bar horizontal di bawah teks
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
    );
  }
}
