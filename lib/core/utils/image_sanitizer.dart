import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Re-encodes as JPEG without EXIF (GPS, device) and caps the long edge.
/// Throws [FormatException] for anything that cannot be decoded.
Future<Uint8List> sanitizeImage(Uint8List bytes, {int maxEdge = 2048}) =>
    compute(_sanitize, (bytes, maxEdge));

Uint8List _sanitize((Uint8List, int) args) {
  final (bytes, maxEdge) = args;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Bild konnte nicht gelesen werden.');
    }
    var image = img.bakeOrientation(decoded);
    if (image.width > maxEdge || image.height > maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: maxEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: maxEdge,
              interpolation: img.Interpolation.average,
            );
    }
    image.exif = img.ExifData();
    return img.encodeJpg(image, quality: 85);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Bild konnte nicht gelesen werden.');
  }
}
