import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class HudComponent extends PositionComponent with HasGameRef<KurirGame> {
  late TextComponent distanceText;
  late TextComponent coinText;
  late SpriteComponent
  coinIcon; // Kita gunakan SpriteComponent untuk gambar aset
  Sprite? heartSprite; // Sprite langsung untuk gambar aset nyawa (hati)

  // Palet Warna Panel UI Pixel Art Retro (Solid, tanpa transparansi)
  final Paint _panelBorderPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _panelShadowPaint = Paint()..color = const Color(0xFF111111);
  final Paint _panelBgPaint = Paint()
    ..color = const Color(0xFF2A2A35); // Biru dongker gelap khas RPG

  // Simpan warna Paint di awal agar tidak dibuat berulang di fungsi render (Anti-Lag)
  final Paint _magnetFillPaint = Paint()..color = Colors.lightBlueAccent;
  final Paint _shieldFillPaint = Paint()..color = Colors.greenAccent;

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
          fontFamily: 'PixelFont', // Font Retro Pixel
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
          fontFamily: 'PixelFont', // Font Retro Pixel
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

    // 4. Setup Aset Gambar Nyawa (Hearts)
    try {
      heartSprite = Sprite(gameRef.images.fromCache('heart.png'));
    } catch (e) {
      // Biarkan kosong dengan aman jika gambar heart.png belum tersedia
    }
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

    // Responsif: Posisikan elemen UI dengan tepat
    // Posisi Indikator Jarak (Di Kiri Atas)
    distanceText.position = Vector2(85, 43);

    // Posisi Indikator Koin dan Gambar Asetnya (Di Bawah Indikator Jarak)
    coinIcon.position = Vector2(40, 99);
    coinText.position = Vector2(80, 99);
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
  void renderTree(Canvas canvas) {
    // Blokir render tree agar background beserta seluruh teks/ikon anaknya tersembunyi
    if (gameRef.isMainMenu) return;
    super.renderTree(canvas);
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

    // --- Render Gambar Hati (Nyawa) di Atas Panel ---
    if (heartSprite != null) {
      int lives = gameRef.playerLives;
      if (lives < 0) lives = 0;

      double startX =
          gameRef.size.x - 135.0; // Margin kiri sedikit ke dalam panel
      double yPos = 28.0; // Tinggi rata tengah panel

      for (int i = 0; i < lives; i++) {
        heartSprite!.render(
          canvas,
          position: Vector2(
            startX + (i * 35.0),
            yPos,
          ), // Geser 35 pixel per gambar
          size: Vector2(
            30,
            30,
          ), // Ukuran gambar hati (Silakan sesuaikan jika kurang pas!)
        );
      }
    }

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

    // --- Indikator Bar Shield (Hanya muncul jika shield aktif) ---
    if (gameRef.player.hasShield) {
      // Jika magnet aktif, taruh shield di bawah bar magnet, jika tidak taruh di tempat magnet
      double yOffset = gameRef.player.isMagnetActive ? 104.0 : 76.0;
      final shieldBg = Rect.fromLTWH(gameRef.size.x - 150, yOffset, 130, 22);

      // Gambar frame bar shield dengan style retro
      canvas.drawRect(shieldBg.translate(3, 3), _panelShadowPaint); // Shadow
      canvas.drawRect(shieldBg, _panelBorderPaint); // Border Putih
      canvas.drawRect(
        shieldBg.deflate(3),
        _panelShadowPaint,
      ); // Base Hitam Dalam

      // Isi Bar Shield (Warna hijau menyusut)
      double ratio = (gameRef.player.shieldDuration / 10.0).clamp(0.0, 1.0);
      if (ratio > 0) {
        final fillRect = Rect.fromLTWH(
          shieldBg.left + 3,
          shieldBg.top + 3,
          (shieldBg.width - 6) * ratio,
          shieldBg.height - 6,
        );
        canvas.drawRect(fillRect, _shieldFillPaint);
      }
    }

    // Lanjutkan render normal (teks & ikon koin dari komponen)
    super.render(canvas);
  }
}
