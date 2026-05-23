import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class HudComponent extends PositionComponent with HasGameRef<KurirGame> {
  late TextComponent distanceText;
  late TextComponent coinText;
  late SpriteComponent
  coinIcon; // Kita gunakan SpriteComponent untuk gambar aset
  late TextComponent livesText; // Tambahkan deklarasi untuk teks nyawa (hati)

  // Palet Warna Panel UI Pixel Art Retro (Solid, tanpa transparansi)
  final Paint _panelBorderPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _panelShadowPaint = Paint()..color = const Color(0xFF111111);
  final Paint _panelBgPaint = Paint()
    ..color = const Color(0xFF2A2A35); // Biru dongker gelap khas RPG

  // Simpan warna Paint di awal agar tidak dibuat berulang di fungsi render (Anti-Lag)
  final Paint _magnetFillPaint = Paint()..color = Colors.lightBlueAccent;

  HudComponent() : super(priority: 100);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Setup Ikon Koin menggunakan aset sprite 'koin.png' dari folder assets/images/
    coinIcon = SpriteComponent(
      sprite: Sprite(gameRef.images.fromCache('koin.png')),
      size: Vector2(
        84, // Diperbesar 3X lipat dari sebelumnya (28)
        84,
      ), // Gambar akan sengaja sedikit 'keluar' dari kotak layaknya UI Retro
      anchor: Anchor.center,
    );
    add(coinIcon);

    // 2. Setup Teks Jumlah Koin
    coinText = TextComponent(
      text: '0',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFD700), // Warna Emas
          fontSize: 22,
          fontWeight: FontWeight.w900,
          shadows: [
            // blurRadius 0 menghasilkan bayangan kotak yang tajam khas Pixel Art!
            Shadow(color: Colors.black, blurRadius: 0, offset: Offset(3, 3)),
          ],
        ),
      ),
      anchor: Anchor.centerLeft,
    );
    add(coinText);

    // 3. Setup Teks Jarak Tempuh (Milestone)
    distanceText = TextComponent(
      text: '0 M',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00E5FF), // Warna Cyan Neon retro
          fontSize: 22,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 0, offset: Offset(3, 3)),
          ],
        ),
      ),
      anchor: Anchor.center,
    );
    add(distanceText);

    // 4. Setup Teks Nyawa (Hearts)
    livesText = TextComponent(
      text: '❤️❤️❤️', // Placeholder awal
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 20,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 0, offset: Offset(3, 3)),
          ],
        ),
      ),
      anchor: Anchor.center,
    );
    add(livesText);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Mencegah TextComponent nge-repaint (sangat memakan CPU) jika isi teksnya tidak berubah
    final newDistance = '${gameRef.distanceTravelled.toInt()} M';
    if (distanceText.text != newDistance) {
      distanceText.text = newDistance;
    }

    final newCoin = '${gameRef.currentCoins}';
    if (coinText.text != newCoin) {
      coinText.text = newCoin;
    }

    // Update jumlah nyawa (Mencegah error string jika nyawa minus)
    int lives = gameRef.playerLives;
    if (lives < 0) lives = 0;
    final newLives = '❤️' * lives;
    if (livesText.text != newLives) {
      livesText.text = newLives;
    }

    // Responsif: Posisikan elemen UI dengan tepat
    // Posisi Indikator Jarak (Di Kiri Atas)
    distanceText.position = Vector2(85, 43);

    // Posisi Indikator Koin dan Gambar Asetnya (Di Bawah Indikator Jarak)
    coinIcon.position = Vector2(40, 99);
    coinText.position = Vector2(80, 99);

    // Posisi Indikator Nyawa (Di Kanan Atas Layar)
    livesText.position = Vector2(gameRef.size.x - 85, 43);
  }

  // Helper untuk menggambar panel ala Pixel Art RPG
  void _drawRetroPanel(Canvas canvas, Rect rect) {
    // 1. Drop shadow luar yang kaku
    canvas.drawRect(rect.translate(4, 4), _panelShadowPaint);
    // 2. Garis luar (Border) tebal warna putih
    canvas.drawRect(rect, _panelBorderPaint);
    // 3. Garis dalam (Inner Border) warna hitam
    canvas.drawRect(rect.deflate(3), _panelShadowPaint);
    // 4. Latar warna solid
    canvas.drawRect(rect.deflate(6), _panelBgPaint);
  }

  @override
  void render(Canvas canvas) {
    // Background Indikator Jarak
    final distanceBg = Rect.fromLTWH(20, 20, 130, 46);
    _drawRetroPanel(canvas, distanceBg);

    // Background Indikator Koin
    final coinBg = Rect.fromLTWH(20, 76, 130, 46);
    _drawRetroPanel(canvas, coinBg);

    // Background Indikator Nyawa
    final livesBg = Rect.fromLTWH(gameRef.size.x - 150, 20, 130, 46);
    _drawRetroPanel(canvas, livesBg);

    // --- Indikator Bar Magnet (Hanya muncul jika magnet aktif) ---
    if (gameRef.player.isMagnetActive) {
      // Kotak Background Bar Magnet (Lebar sama dengan nyawa, posisi di bawahnya)
      final magnetBg = Rect.fromLTWH(gameRef.size.x - 150, 76, 130, 22);

      // Gambar frame bar magnet dengan style retro
      canvas.drawRect(magnetBg.translate(3, 3), _panelShadowPaint); // Shadow
      canvas.drawRect(magnetBg, _panelBorderPaint); // Border Putih
      canvas.drawRect(
        magnetBg.deflate(3),
        _panelShadowPaint,
      ); // Base Hitam Dalam

      // Isi Bar Magnet (Warna biru menyusut)
      double ratio = (gameRef.player.magnetDuration / 10.0).clamp(0.0, 1.0);
      if (ratio > 0) {
        final fillRect = Rect.fromLTWH(
          magnetBg.left + 3,
          magnetBg.top + 3,
          (magnetBg.width - 6) * ratio,
          magnetBg.height - 6,
        );
        canvas.drawRect(fillRect, _magnetFillPaint);
      }
    }

    // Lanjutkan render normal (teks & ikon koin dari komponen)
    super.render(canvas);
  }
}
