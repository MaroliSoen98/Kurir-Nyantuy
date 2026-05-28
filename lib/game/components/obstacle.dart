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

  Sprite? sprite;
  Sprite? spriteDepan;
  Sprite? spriteTengah;
  Sprite? spriteBelakang;
  late Paint fallbackPaint;

  static final Random _sharedRandom = Random(); // Random global untuk efisiensi

  // Variabel untuk Obstacle Chaotic (Ibu-ibu / Angkot Nge-Drift)
  double targetWorldX;
  bool isEmakEmak = false;
  bool _isTargetCalculated = false;
  bool hasTriggeredText = false; // Penanda kapan teks mulai muncul
  bool hasTriggeredMove = false;
  double textTriggerZ = 0; // Jarak Z kapan teks muncul
  double moveTriggerZ = 0;
  String? memeText;

  // Path untuk menggambar ekor bubble chat (Dibuat sekali untuk cegah memori bocor)
  final Path _tailPath = Path();

  // Simpan gaya Text secara statis agar tidak membebani memori (Mencegah Lag)
  static final TextPaint _senPaint = TextPaint(
    style: const TextStyle(
      fontFamily: 'PixelFont', // Font Retro Pixel
      color: Colors.black, // Warna hitam pekat ala komik
      fontSize: 22,
      fontWeight: FontWeight.w900, // Sangat tebal biar makin jelas
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
  }) : targetWorldX = worldX,
       super(anchor: Anchor.bottomCenter) {
    if (isFloating) {
      worldY = -80.0; // Posisikan melayang di udara
    }

    // Logika Emak-emak Chaotic (Pindah Jalur Mendadak)
    if (!isSmall && !isFloating) {
      double roll = _sharedRandom.nextDouble();

      if (roll < 0.95) {
        // 95% Kemungkinan bergerak kacau, sisa 5% cuma jalan lurus
        isEmakEmak = true;

        // Teks dipaksa muncul dari jarak terjauh secara instan (bertahan ~2 hingga 3 detik)
        textTriggerZ = worldZ;

        // Rintangan baru akan dieksekusi belok saat posisinya lebih jauh (Jarak 1100) agar pemain siap!
        moveTriggerZ = 1100.0;
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
        // [OPTIMALISASI FPS] Jarak layer direnggangkan sedikit ke 60.0 (Sebelumnya 25.0).
        // Jarak 25.0 terlalu rapat dan memicu 96x draw-call untuk 1 rintangan terowongan panjang.
        double layerSpacing = 60.0;
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

    // Teks muncul jelas dan HILANG tepat saat dia mulai belok (!hasTriggeredMove)
    if (isEmakEmak &&
        hasTriggeredText &&
        !hasTriggeredMove &&
        memeText != null) {
      canvas.save();

      // Sesuaikan skala teks dengan proyeksi 3D agar terlihat natural
      final textScale = max(0.4, gameRef.getScale(worldZ));

      // Geser titik render teks ke atas kepala karakter.
      // Dikalikan dengan textScale agar jarak pop-up merapat dan tidak terbang terlalu tinggi saat jauh.
      canvas.translate(size.x / 2, -35 * textScale);

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

    // Logika Pintar: Kalkulasi lajur pindah ibu-ibu secara dinamis untuk menghindari tabrakan
    if (isEmakEmak && !_isTargetCalculated) {
      // Temukan semua rintangan di kedalaman Z yang sama (Satu baris / pattern yang sama)
      List<Obstacle> rowObstacles = [];
      for (final child in gameRef.children) {
        if (child is Obstacle && !child.isRemoving) {
          if ((child.worldZ - this.worldZ).abs() < 100.0) {
            rowObstacles.add(child);
          }
        }
      }

      // Ambil yang isEmakEmak dan urutkan posisinya dari kiri ke kanan
      List<Obstacle> emaks = rowObstacles.where((o) => o.isEmakEmak).toList();
      emaks.sort((a, b) => a.worldX.compareTo(b.worldX));

      if (emaks.length == 1) {
        // --- Skenario 1 Ibu-ibu saja (Hanya Pindah 1 Lajur) ---
        int currentLane = (worldX / 180.0).round();
        List<int> availableLanes = [-1, 0, 1];
        availableLanes.remove(currentLane);

        // Hindari lajur posisi rintangan diam (tembok / galian)
        for (final obs in rowObstacles) {
          if (!obs.isEmakEmak) {
            int obsLane = (obs.worldX / 180.0).round();
            availableLanes.remove(obsLane);
          }
        }

        // Batasi pergerakan hanya sejauh 1 lajur
        List<int> oneLaneMoves = availableLanes
            .where((l) => (l - currentLane).abs() == 1)
            .toList();

        if (oneLaneMoves.isNotEmpty) {
          int targetLane =
              oneLaneMoves[_sharedRandom.nextInt(oneLaneMoves.length)];
          targetWorldX = targetLane * 180.0;
        } else {
          isEmakEmak = false; // Batal nge-drift jika jalan terhalang
        }

        _isTargetCalculated = true;
        if (isEmakEmak) {
          memeText = (targetWorldX > worldX) ? "KIRI" : "KANAN";
        }
      } else if (emaks.length == 2) {
        // --- Skenario 2 Ibu-ibu Bersebelahan ---
        Obstacle leftEmak = emaks[0];
        Obstacle rightEmak = emaks[1];

        // Pastikan kalkulasi hanya dilakukan sekali saat salah satu dari mereka pertama kali update
        if (!leftEmak._isTargetCalculated || !rightEmak._isTargetCalculated) {
          int lCurrent = (leftEmak.worldX / 180.0).round();
          int rCurrent = (rightEmak.worldX / 180.0).round();

          if (lCurrent == -1 && rCurrent == 1) {
            // Skenario Kiri & Kanan: Salah satu ke tengah, satu diam.
            if (_sharedRandom.nextBool()) {
              leftEmak.targetWorldX = 0.0;
              rightEmak.isEmakEmak = false;
              rightEmak.targetWorldX = 180.0;
            } else {
              rightEmak.targetWorldX = 0.0;
              leftEmak.isEmakEmak = false;
              leftEmak.targetWorldX = -180.0;
            }
          } else if (lCurrent == -1 && rCurrent == 0) {
            // Skenario Kiri & Tengah: Bergerak ke kanan bersama, atau hanya tengah yang ke kanan.
            if (_sharedRandom.nextBool()) {
              leftEmak.targetWorldX = 0.0;
              rightEmak.targetWorldX = 180.0;
            } else {
              leftEmak.isEmakEmak = false;
              leftEmak.targetWorldX = -180.0;
              rightEmak.targetWorldX = 180.0;
            }
          } else if (lCurrent == 0 && rCurrent == 1) {
            // Skenario Tengah & Kanan: Bergerak ke kiri bersama, atau hanya tengah yang ke kiri.
            if (_sharedRandom.nextBool()) {
              leftEmak.targetWorldX = -180.0;
              rightEmak.targetWorldX = 0.0;
            } else {
              leftEmak.targetWorldX = -180.0;
              rightEmak.isEmakEmak = false;
              rightEmak.targetWorldX = 180.0;
            }
          } else {
            // Default aman
            leftEmak.isEmakEmak = false;
            rightEmak.isEmakEmak = false;
          }

          leftEmak._isTargetCalculated = true;
          rightEmak._isTargetCalculated = true;

          if (leftEmak.isEmakEmak)
            leftEmak.memeText = (leftEmak.targetWorldX > leftEmak.worldX)
                ? "KIRI"
                : "KANAN";
          if (rightEmak.isEmakEmak)
            rightEmak.memeText = (rightEmak.targetWorldX > rightEmak.worldX)
                ? "KIRI"
                : "KANAN";
        }
      } else if (emaks.length >= 3) {
        // Jika 3 lajur penuh dengan emak-emak, batalkan semua agar pemain bisa lewat dari celah lompatan atas
        for (var emak in emaks) {
          if (!emak._isTargetCalculated) {
            emak.isEmakEmak = false;
            emak._isTargetCalculated = true;
          }
        }
      }
    }

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
