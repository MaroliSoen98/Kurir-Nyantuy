import 'package:flutter/material.dart';
import 'dart:math' as math;

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({super.key});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Controller berulang dari 0.0 ke 1.0 terus menerus selama 600ms (ngebut!)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Fungsi untuk menggambar lingkaran asap buatan
  Widget _buildSmoke(double progress) {
    return Transform.translate(
      // Asap bergerak ke kiri (belakang motor) dan sedikit ke atas
      offset: Offset(-30 - (progress * 60), 30 - (progress * 30)),
      child: Transform.scale(
        // Asap membesar perlahan
        scale: 0.5 + (progress * 1.5),
        child: Opacity(
          // Asap memudar saat semakin besar
          opacity: 1.0 - progress,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white70, // Putih transparan layaknya asap
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 180,
              width: 200,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Rumus getaran motor naik turun (Bouncing)
                  final bounce = math.sin(_controller.value * math.pi * 2) * 8;
                  // Rumus motor sedikit miring naik turun (Nge-gas)
                  final angle =
                      math.cos(_controller.value * math.pi * 2) * 0.05;

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Partikel Asap 1
                      _buildSmoke((_controller.value + 0.0) % 1.0),
                      // Partikel Asap 2 (Selang-seling waktu dengan asap 1)
                      _buildSmoke((_controller.value + 0.5) % 1.0),

                      // Motor Utama
                      Transform.translate(
                        offset: Offset(0, bounce),
                        child: Transform.rotate(angle: angle, child: child),
                      ),
                    ],
                  );
                },
                // Kita langsung pakai aset motor.png dari folder Anda biar serasi!
                child: Image.asset(
                  'assets/images/motor.png',
                  width: 150,
                  height: 150,
                  // Fallback jika tidak ditemukan
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.motorcycle,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 2. Teks loading
            const Text(
              'LAGI MANASIN MOTOR..', // Nuansa santuy
              style: TextStyle(
                fontFamily: 'PixelFont',
                fontSize: 40,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 0,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 3. Loading bar horizontal retro Arcade Style
            Container(
              width: 220,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                color: Colors.black,
              ),
              child: LinearProgressIndicator(
                color: const Color(0xFF39FF14), // Hijau Nyala Neon
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
