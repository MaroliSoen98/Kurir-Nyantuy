import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../kurir_game.dart';

class Obstacle extends PositionComponent with HasGameRef<KurirGame> {
  double worldX;
  double worldY = 0;
  double worldZ;
  final Vector2 baseSize;
  final bool isSmall; // Membedakan rintangan ringan dan fatal
  final bool isFloating; // Membedakan rintangan melayang (Portal)

  Sprite? sprite;
  late Paint fallbackPaint;

  static final Random _sharedRandom = Random(); // Random global untuk efisiensi

  // Variabel untuk Obstacle Chaotic (Ibu-ibu / Angkot Nge-Drift)
  double targetWorldX;
  bool isEmakEmak = false;
  bool hasTriggeredText = false; // Penanda kapan teks mulai muncul
  bool hasTriggeredMove = false;
  double textTriggerZ = 0; // Jarak Z kapan teks muncul
  double moveTriggerZ = 0;
  double blinkTimer = 0;
  String? memeText;

  // Path untuk menggambar ekor bubble chat (Dibuat sekali untuk cegah memori bocor)
  final Path _tailPath = Path();

  // Simpan gaya Text secara statis agar tidak membebani memori (Mencegah Lag)
  static final TextPaint _senPaint = TextPaint(
    style: const TextStyle(
      color: Colors.redAccent, // Warna merah tegas
      fontSize: 22,
      fontWeight: FontWeight.w600, // Semi-bold, lebih clean dan mudah terbaca
      letterSpacing: 1.0,
    ),
  );

  // Simpan gaya coretan Bubble Chat secara statis (Mencegah Lag)
  static final Paint _bubbleBgPaint = Paint()..color = Colors.white;
  static final Paint _bubbleBorderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
  static final Paint _bubbleWipePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.0; // Untuk menghapus garis perbatasan ekor dan bubble

  // Simpan objek statis untuk mencegah Memory Leak / Frame Drop di fungsi render!
  static final Paint _pixelPaint = Paint()..filterQuality = FilterQuality.none;
  static final RRect _bubbleRect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: 90, height: 36),
    const Radius.circular(12),
  );

  Obstacle({
    required this.worldX,
    required this.worldZ,
    required this.baseSize,
    this.isSmall = false,
    this.isFloating = false,
  }) : targetWorldX = worldX,
       super(anchor: Anchor.bottomCenter) {
    if (isFloating) {
      worldY = -80.0; // Posisikan melayang di udara
    }

    // Logika Emak-emak Chaotic (Pindah Jalur Mendadak)
    if (!isSmall && !isFloating) {
      if (_sharedRandom.nextDouble() < 0.50) {
        // 50% kemungkinan obstacle besar nge-drift, 50% tetap lurus (Sangat tak tertebak!)
        isEmakEmak = true;
        int currentLane = (worldX / 180.0).round();
        List<int> possibleLanes = [-1, 0, 1]..remove(currentLane);

        // Pilih lajur target secara acak
        int targetLane =
            possibleLanes[_sharedRandom.nextInt(possibleLanes.length)];
        targetWorldX = targetLane * 180.0;

        // Jarak (Z) teks muncul LEBIH AWAL dari pergerakan
        textTriggerZ = 1600.0 + _sharedRandom.nextDouble() * 300.0;

        // Pergerakan belok terjadi SETELAH teks muncul (Sekitar 500 unit lebih dekat ke layar)
        moveTriggerZ = textTriggerZ - 500.0;

        // Efek Meme Absurd: Tulisan "Sen" selalu kebalikan dari arah aslinya
        memeText = (targetWorldX > worldX) ? "KIRI" : "KANAN";
      }
    }

    // Simpan warna kotak sebagai cadangan jika gambar belum siap
    fallbackPaint = Paint()
      ..color = isFloating
          ? Colors.blueGrey
          : (isSmall ? Colors.brown : Colors.redAccent);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Coba muat gambar sprite, jika gagal maka akan tetap null dan pakai warna fallback
    try {
      String imageName = isFloating
          ? 'portal.png'
          : (isSmall ? 'kucing.png' : 'ibumotor.png');
      sprite = Sprite(
        gameRef.images.fromCache(imageName),
      ); // Panggil Instan dari Cache
    } catch (e) {
      // Jangan print error agar terminal tidak spam, game otomatis pakai kotak warna
    }

    // Tambahkan Hitbox untuk deteksi tabrakan yang pas dengan ukuran kotak
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (sprite != null) {
      // Render gambar pixel art jika asetnya sudah ada
      sprite!.render(
        canvas,
        size: size,
        overridePaint: _pixelPaint, // Gunakan paint statis (ANTI LAG)
      );
    } else {
      // Render kotak warna jika asetnya belum ada
      canvas.drawRect(size.toRect(), fallbackPaint);
    }

    // Render efek pop-up teks meme yang nge-blink saat belok
    if (isEmakEmak &&
        hasTriggeredText &&
        blinkTimer < 0.2 &&
        memeText != null) {
      canvas.save();
      // Geser titik render teks ke atas kepala karakter (ditinggikan agar tidak menutupi gambar motor)
      canvas.translate(size.x / 2, -60);

      // Sesuaikan skala teks dengan proyeksi 3D agar terlihat natural
      final textScale = max(0.4, gameRef.getScale(worldZ));
      canvas.scale(textScale);

      // Menggambar Bubble Chat (Kotak Melengkung Putih)
      canvas.drawRRect(_bubbleRect, _bubbleBgPaint);
      canvas.drawRRect(_bubbleRect, _bubbleBorderPaint);

      // Menggambar Ekor Bubble (Segitiga di bawah kotak)
      _tailPath.reset();
      _tailPath
        ..moveTo(-8, _bubbleRect.bottom)
        ..lineTo(8, _bubbleRect.bottom)
        ..lineTo(0, _bubbleRect.bottom + 12)
        ..close();
      canvas.drawPath(_tailPath, _bubbleBgPaint);
      canvas.drawPath(_tailPath, _bubbleBorderPaint);

      // Menghapus garis batas hitam antara kotak dan ekor agar menyatu
      canvas.drawLine(
        Offset(-6, _bubbleRect.bottom),
        Offset(6, _bubbleRect.bottom),
        _bubbleWipePaint,
      );

      _senPaint.render(
        canvas,
        memeText!,
        Vector2.zero(), // Tepat di tengah bubble berkat Offset.zero
        anchor: Anchor.center, // Centering text sempurna
      );
      canvas.restore();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gerakkan rintangan mendekat ke posisi kamera (Z berkurang)
    worldZ -= gameRef.gameSpeed * dt;

    // Hapus rintangan jika sudah melewati batas belakang layar
    if (worldZ < -100) {
      removeFromParent();
      return;
    }

    // Logika Pergerakan Chaotic Ibu-ibu
    if (isEmakEmak) {
      if (worldZ < textTriggerZ) {
        hasTriggeredText = true;
      }

      if (worldZ < moveTriggerZ) {
        hasTriggeredMove = true;
      }

      // Teks sudah mulai berkedip SEBELUM motor belok
      if (hasTriggeredText) {
        blinkTimer += dt;
        if (blinkTimer > 0.4) blinkTimer = 0;
      }

      if (hasTriggeredMove) {
        // Interpolasi perpindahan jalur mendadak & lincah
        double dx = targetWorldX - worldX;
        worldX += dx * 7.0 * dt;

        // Efek Lean (Miring Berbelok) + Sedikit Wobble (Motor Oleng)
        angle = (dx * 0.005).clamp(-0.35, 0.35) + (sin(worldZ * 0.1) * 0.05);
      }
    }

    // Terapkan Proyeksi Skala Pseudo-3D
    final scale = gameRef.getScale(worldZ);
    size = baseSize * scale;
    position = Vector2(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }
}
