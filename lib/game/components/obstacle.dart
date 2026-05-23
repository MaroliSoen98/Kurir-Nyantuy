import 'package:flame/components.dart';
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
  final double depthZ; // Kedalaman rintangan ke belakang
  final bool canDrift; // Penentu apakah emak-emak boleh pindah jalur

  Sprite? sprite;
  Sprite? spriteDepan;
  Sprite? spriteTengah;
  Sprite? spriteBelakang;
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

  // Objek Statis Anti-Lag untuk proses render Z-Sliced 2.5D
  static final Path _trenchPath = Path();
  static final Vector2 _cachedRenderPos = Vector2.zero();
  static final Vector2 _cachedRenderSize = Vector2.zero();
  static final Vector2 _zeroVec = Vector2.zero();

  Obstacle({
    required this.worldX,
    required this.worldZ,
    required this.baseSize,
    this.isSmall = false,
    this.isFloating = false,
    this.depthZ = 0.0,
    this.canDrift = true,
  }) : targetWorldX = worldX,
       super(anchor: Anchor.bottomCenter) {
    if (isFloating) {
      worldY = -80.0; // Posisikan melayang di udara
    }

    // Logika Emak-emak Chaotic (Pindah Jalur Mendadak)
    if (!isSmall && !isFloating && canDrift) {
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
          ? Colors
                .blueGrey // Portal
          : (isSmall
                ? Colors.pink.shade100
                : Colors.redAccent); // Galian vs Ibu-ibu
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Muat gambar sprite jika ada. Rintangan 'galian' (isSmall) tidak punya
    // gambar dan akan menggunakan warna fallback (pink muda).
    try {
      if (isSmall && depthZ > 0) {
        // Load 3 layer terpisah khusus untuk Galian 2.5D Z-Sliced
        spriteDepan = Sprite(gameRef.images.fromCache('galian_depan.png'));
        spriteTengah = Sprite(gameRef.images.fromCache('galian_tengah.png'));
        spriteBelakang = Sprite(
          gameRef.images.fromCache('galian_belakang.png'),
        );
      } else {
        String imageName = isFloating ? 'portal.png' : 'ibumotor.png';
        sprite = Sprite(gameRef.images.fromCache(imageName));
      }
    } catch (e) {
      // Jangan print error agar terminal tidak spam, game otomatis pakai kotak warna
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (depthZ > 0 && !isFloating) {
      final clampedZFront = max(-200.0, worldZ);
      final scaleFront = gameRef.getScale(clampedZFront);
      final frontScreenX = (gameRef.size.x / 2) + (worldX * scaleFront);
      final frontScreenY =
          gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scaleFront);

      if (spriteDepan != null &&
          spriteTengah != null &&
          spriteBelakang != null) {
        // --- SISTEM 2.5D Z-SLICING ---
        // Menggambar objek berdasarkan kedalaman murni. Tidak butuh pemotongan (ClipPath)
        // sehingga cone dan barikade bisa pop-out menonjol ke luar aspal dengan sangat realistis!
        void drawZLayer(Sprite spr, double zPos) {
          if (zPos < -200) return; // Abaikan jika sudah di belakang layar

          double clampedZ = max(-200.0, zPos);
          double s = gameRef.getScale(clampedZ);

          // Lebar menyesuaikan skala, tinggi proporsional asli (Anti-Gepeng)
          double w = baseSize.x * s;
          double h = w * (spr.image.height / spr.image.width);

          double screenX = (gameRef.size.x / 2) + (worldX * s);
          double screenY =
              gameRef.horizonY + ((gameRef.cameraHeight + worldY) * s);

          double localCenterX = (screenX - frontScreenX) + size.x / 2;
          double localBottomY = (screenY - frontScreenY) + size.y;

          _cachedRenderPos.setValues(localCenterX - w / 2, localBottomY - h);
          _cachedRenderSize.setValues(w, h);

          spr.render(
            canvas,
            position: _cachedRenderPos,
            size: _cachedRenderSize,
            overridePaint: _pixelPaint,
          );
        }

        // 1. Render Bagian Paling Belakang
        drawZLayer(spriteBelakang!, worldZ + depthZ);

        // 2. Render Bagian Tengah (Berulang dengan jarak SANGAT RAPAT)
        // Kita ubah jarak antar potongan menjadi 25.0 agar layering-nya tumpang tindih padat.
        // Semakin rapat, ilusi 3D (volume galian) akan semakin menyatu dan tidak terputus.
        double layerSpacing = 25.0;
        int numMiddleTiles = max(1, (depthZ / layerSpacing).round());
        double step = depthZ / (numMiddleTiles + 1);

        for (int i = numMiddleTiles; i >= 1; i--) {
          drawZLayer(spriteTengah!, worldZ + (i * step));
        }

        // 3. Render Bagian Paling Depan
        drawZLayer(spriteDepan!, worldZ);
      } else {
        // Fallback jika gambar rusak/belum load
        final clampedZBack = max(-200.0, worldZ + depthZ);
        final scaleBack = gameRef.getScale(clampedZBack);
        final widthBack = baseSize.x * scaleBack;
        final widthFront = baseSize.x * scaleFront;
        final shiftX = worldX * (scaleBack - scaleFront);

        _trenchPath.reset();
        _trenchPath
          ..moveTo((size.x / 2) + shiftX - (widthBack / 2), 0)
          ..lineTo((size.x / 2) + shiftX + (widthBack / 2), 0)
          ..lineTo((size.x / 2) + (widthFront / 2), size.y)
          ..lineTo((size.x / 2) - (widthFront / 2), size.y)
          ..close();

        canvas.drawPath(_trenchPath, fallbackPaint);
      }
    } else {
      // Render Obstacle Biasa (Bukan galian)
      if (sprite != null) {
        sprite!.render(canvas, size: size, overridePaint: _pixelPaint);
      } else {
        canvas.drawRect(size.toRect(), fallbackPaint);
      }
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
        _zeroVec, // Menggunakan static vector agar tidak mengalokasi memory baru tiap frame
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

    // Hapus rintangan jika seluruh bagiannya melewati batas belakang layar
    if (worldZ + depthZ < -200) {
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
    final clampedZ = max(-200.0, worldZ);
    final scale = gameRef.getScale(clampedZ);

    double compWidth = baseSize.x * scale;
    double compHeight = baseSize.y * scale;

    if (depthZ > 0 && !isFloating) {
      // Wajib mengunci tinggi kotak komponen tepat dari ujung depan ke ujung belakang aspal
      final clampedZBack = max(-200.0, worldZ + depthZ);
      final scaleBack = gameRef.getScale(clampedZBack);
      final yFront =
          gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale);
      final yBack =
          gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scaleBack);
      compHeight = max(1.0, yFront - yBack);
    }

    size.setValues(compWidth, compHeight);
    position.setValues(
      (gameRef.size.x / 2) + (worldX * scale),
      gameRef.horizonY + ((gameRef.cameraHeight + worldY) * scale),
    );
  }
}
