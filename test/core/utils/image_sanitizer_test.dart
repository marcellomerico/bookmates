import 'dart:typed_data';

import 'package:bookmates/core/utils/image_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('removes EXIF and caps the long edge', () async {
    final source = img.Image(width: 3000, height: 1000);
    source.exif.imageIfd['Make'] = 'SpyCam';
    source.exif.gpsIfd[0x1] = img.IfdValueAscii('N');
    final jpg = img.encodeJpg(source);
    final before = img.decodeJpgExif(jpg);
    expect(before?.imageIfd['Make'], isNotNull, reason: 'fixture must carry EXIF');
    expect(before?.gpsIfd.isEmpty, isFalse, reason: 'fixture must carry GPS');

    final out = await sanitizeImage(Uint8List.fromList(jpg));

    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 2048);
    expect(decoded.height, closeTo(683, 1));
    expect(decoded.exif.imageIfd['Make'], isNull);
    expect(decoded.exif.gpsIfd.isEmpty, isTrue);
  });

  test('leaves small images at their size', () async {
    final out = await sanitizeImage(
      Uint8List.fromList(img.encodeJpg(img.Image(width: 400, height: 300))),
      maxEdge: 512,
    );
    expect(img.decodeJpg(out)!.width, 400);
  });
}
