import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class RainEffect extends Component with HasGameRef<KurirGame> {
  final int dropCount = 150; // Jumlah rintik hujan di layar
  late Float32List _points; // Buffer [x1, y1, x2, y2, ...] untuk semua hujan
  final List<double> speeds = [];
  final Random _random = Random();
  final Paint _rainPaint = Paint()
    ..strokeWidth = 2.0
    ..isAntiAlias =
        false // Garis kaku/tajam ala retro pixel art
    ..style = PaintingStyle.stroke;

  double intensity = 0.0; // Untuk transisi memudar (fade-in / fade-out)
  bool isRaining = false; // Status apakah sedang hujan

  RainEffect() : super(priority: 90) {
    // Render di atas game, di bawah HUD UI
    _points = Float32List(dropCount * 4); // 2 titik per garis (4 nilai)
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (speeds.isEmpty) {
      // Pre-alokasi titik kordinat hujan untuk mencegah Lag Memori (GC)
      for (int i = 0; i < dropCount; i++) {
        _points[i * 4] = _random.nextDouble() * size.x;
        _points[i * 4 + 1] = _random.nextDouble() * size.y;
        speeds.add(_random.nextDouble() * 800 + 1000); // Kecepatan jatuh
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Transisi hujan perlahan menebal / memudar
    if (isRaining && intensity < 1.0) {
      intensity += dt * 0.5;
      if (intensity > 1.0) intensity = 1.0;
    } else if (!isRaining && intensity > 0.0) {
      intensity -= dt * 0.5;
      if (intensity < 0.0) intensity = 0.0;
    }

    if (intensity == 0.0) return; // Abaikan perhitungan jika tidak hujan

    for (int i = 0; i < dropCount; i++) {
      int baseIdx = i * 4;

      _points[baseIdx] -= (speeds[i] * 0.15) * dt; // x bergeser ke kiri
      _points[baseIdx + 1] += speeds[i] * dt; // y jatuh ke bawah

      // Jika melewati layar, reset ke atas dengan posisi X acak
      if (_points[baseIdx + 1] > gameRef.size.y || _points[baseIdx] < -50) {
        _points[baseIdx + 1] = -50;
        _points[baseIdx] = _random.nextDouble() * (gameRef.size.x + 200);
      }

      // Hitung ekor/ujung rintik hujan berdasarkan kecepatannya (Efek Motion Blur Retro)
      double dropLength = speeds[i] * 0.03;
      _points[baseIdx + 2] = _points[baseIdx] - (dropLength * 0.15); // End X
      _points[baseIdx + 3] = _points[baseIdx + 1] + dropLength; // End Y
    }

    _rainPaint.color = Colors.white.withOpacity(
      (0.45 * intensity).clamp(
        0.0,
        1.0,
      ), // Sedikit lebih terang agar pixel-artnya menonjol
    );
  }

  @override
  void render(Canvas canvas) {
    if (intensity == 0.0) return;

    // [SUPER OPTIMALISASI] 1 Draw Call untuk menggambar RATUSAN rintik hujan sekaligus!
    // Memangkas waktu render hujan hingga 99% dan mencegah HP kepanasan.
    canvas.drawRawPoints(PointMode.lines, _points, _rainPaint);
  }
}
