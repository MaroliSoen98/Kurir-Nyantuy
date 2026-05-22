import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../kurir_game.dart';

class HudComponent extends PositionComponent with HasGameRef<KurirGame> {
  late TextComponent distanceText;
  late TextComponent coinText;
  late SpriteComponent
  coinIcon; // Kita gunakan SpriteComponent untuk gambar aset
  late TextComponent livesText; // Tambahkan deklarasi untuk teks nyawa (hati)

  // Warna untuk background UI bergaya kotak retro
  final Paint _bgPaint = Paint()
    ..color = const Color(0x99000000); // Hitam transparan 60%
  final Paint _borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

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
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2)),
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
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2)),
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
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2)),
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
    distanceText.position = Vector2(80, 40);

    // Posisi Indikator Koin dan Gambar Asetnya (Di Bawah Indikator Jarak)
    coinIcon.position = Vector2(50, 100);
    coinText.position = Vector2(90, 100);

    // Posisi Indikator Nyawa (Di Kanan Atas Layar)
    livesText.position = Vector2(gameRef.size.x - 80, 40);
  }

  @override
  void render(Canvas canvas) {
    // Background Indikator Jarak
    final distanceBg = RRect.fromLTRBAndCorners(
      20,
      20,
      140,
      60, // Kordinat kotak (kiri, atas, kanan, bawah)
      topLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(distanceBg, _bgPaint);
    canvas.drawRRect(distanceBg, _borderPaint);

    // Background Indikator Koin (Dipindah tepat di bawah Jarak)
    final coinBg = RRect.fromLTRBAndCorners(
      20,
      80,
      140,
      120,
      topLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(coinBg, _bgPaint);
    canvas.drawRRect(coinBg, _borderPaint);

    // Background Indikator Nyawa (Kotak Kanan Atas)
    final livesBg = RRect.fromLTRBAndCorners(
      gameRef.size.x - 140,
      20,
      gameRef.size.x - 20,
      60,
      topRight: const Radius.circular(8),
      bottomLeft: const Radius.circular(
        8,
      ), // Sudut tumpul berkebalikan dari kotak kiri
    );
    canvas.drawRRect(livesBg, _bgPaint);
    canvas.drawRRect(livesBg, _borderPaint);

    // Lanjutkan render normal (teks & ikon koin dari komponen)
    super.render(canvas);
  }
}
