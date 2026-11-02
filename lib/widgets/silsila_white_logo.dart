import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The supplied brand artwork has a solid purple canvas with white lettering.
/// This variant swaps only pixels belonging to the purple/white palette axis,
/// preserving the original pink and orange marks and antialiased edges.
class SilsilaWhiteLogo extends StatelessWidget {
  const SilsilaWhiteLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  static Future<Uint8List?>? _whiteBytes;

  static Future<Uint8List?> _loadWhiteVariant() async {
    ByteData? source;
    try {
      source = await rootBundle.load('assets/images/silsila_logo.png');
    } catch (_) {
      return null;
    }
    final original = Uint8List.fromList(
      source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
    );
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(original);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return original;
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      const pr = 62.0, pg = 0.0, pb = 125.0;
      const dr = 193.0, dg = 255.0, db = 130.0;
      const lengthSquared = dr * dr + dg * dg + db * db;
      for (var i = 0; i + 3 < bytes.length; i += 4) {
        final r = bytes[i].toDouble();
        final g = bytes[i + 1].toDouble();
        final b = bytes[i + 2].toDouble();
        final vr = r - pr, vg = g - pg, vb = b - pb;
        final t = (vr * dr + vg * dg + vb * db) / lengthSquared;
        if (t < -0.015 || t > 1.015) continue;
        final cr = vr - t * dr;
        final cg = vg - t * dg;
        final cb = vb - t * db;
        if (math.sqrt(cr * cr + cg * cg + cb * cb) > 18) continue;
        bytes[i] = (pr + 255 - r).round().clamp(0, 255).toInt();
        bytes[i + 1] = (255 - g).round().clamp(0, 255).toInt();
        bytes[i + 2] = (pb + 255 - b).round().clamp(0, 255).toInt();
      }
      return bytes;
    } catch (_) {
      return original;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    _whiteBytes ??= _loadWhiteVariant();
    return FutureBuilder<Uint8List?>(
      future: _whiteBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          // Keep the brand mark visible if byte loading is unavailable.
          return Image.asset(
            'assets/images/silsila_logo.png',
            width: width,
            height: height,
            fit: fit,
          );
        }
        return Image.memory(bytes, width: width, height: height, fit: fit);
      },
    );
  }
}
