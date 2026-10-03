import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Shrinks a captured photo to at most 1280px on the long side and about
/// 500 KB, as JPEG, with EXIF and location data removed.
class SnapImageProcessor {
  const SnapImageProcessor();

  static const int maxSide = 1280;
  static const int maxBytes = 500 * 1024;

  Future<Uint8List> prepare(Uint8List input) async {
    final (w, h) = await _size(input);
    final longest = w > h ? w : h;
    final scale = longest > maxSide ? maxSide / longest : 1.0;
    final targetW = (w * scale).round().clamp(1, maxSide);
    final targetH = (h * scale).round().clamp(1, maxSide);

    var quality = 85;
    Uint8List out = input;
    while (true) {
      out = await FlutterImageCompress.compressWithList(
        input,
        minWidth: targetW,
        minHeight: targetH,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false, // strips EXIF and GPS data
      );
      if (out.lengthInBytes <= maxBytes || quality <= 40) break;
      quality -= 10;
    }
    return out;
  }

  Future<(int, int)> _size(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  }
}
