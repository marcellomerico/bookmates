// Renders the Booksquad app icon and splash images from code.
// Run: flutter test tool/branding/render_branding_test.dart
// Output: assets/branding/{icon,icon_foreground,splash}.png
// To use a designer icon later, replace those PNGs and re-run the icon/splash generators.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const burgundy = Color(0xFF7B3140);
const cream = Color(0xFFF7F2E8);
const parchment = Color(0xFFE9DDC8);
const gold = Color(0xFFC7A64B);

/// Open book with a bookmark ribbon, drawn inside [rect].
void paintBook(Canvas canvas, Rect rect) {
  final w = rect.width;
  final h = rect.height;
  Offset p(double x, double y) => Offset(rect.left + x * w, rect.top + y * h);

  // Pages: two slightly curved leaves meeting at the spine.
  Path leaf({required bool left}) {
    final s = left ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(p(0.5, 0.30).dx, p(0.5, 0.30).dy)
      ..quadraticBezierTo(
        p(0.5 + s * 0.16, 0.22).dx,
        p(0.5 + s * 0.16, 0.22).dy,
        p(0.5 + s * 0.40, 0.27).dx,
        p(0.5 + s * 0.40, 0.27).dy,
      )
      ..lineTo(p(0.5 + s * 0.40, 0.75).dx, p(0.5 + s * 0.40, 0.75).dy)
      ..quadraticBezierTo(
        p(0.5 + s * 0.16, 0.70).dx,
        p(0.5 + s * 0.16, 0.70).dy,
        p(0.5, 0.78).dx,
        p(0.5, 0.78).dy,
      )
      ..close();
    return path;
  }

  final pagePaint = Paint()..color = cream;
  final edgePaint = Paint()..color = parchment;

  // Page stack edge (gives depth below the leaves).
  for (final left in [true, false]) {
    final s = left ? -1.0 : 1.0;
    final edge = Path()
      ..moveTo(p(0.5, 0.78).dx, p(0.5, 0.78).dy)
      ..quadraticBezierTo(
        p(0.5 + s * 0.16, 0.70).dx,
        p(0.5 + s * 0.16, 0.70).dy,
        p(0.5 + s * 0.40, 0.75).dx,
        p(0.5 + s * 0.40, 0.75).dy,
      )
      ..lineTo(p(0.5 + s * 0.40, 0.79).dx, p(0.5 + s * 0.40, 0.79).dy)
      ..quadraticBezierTo(
        p(0.5 + s * 0.16, 0.745).dx,
        p(0.5 + s * 0.16, 0.745).dy,
        p(0.5, 0.83).dx,
        p(0.5, 0.83).dy,
      )
      ..close();
    canvas.drawPath(edge, edgePaint);
  }
  canvas.drawPath(leaf(left: true), pagePaint);
  canvas.drawPath(leaf(left: false), pagePaint);

  // Text lines on the pages.
  final linePaint = Paint()
    ..color = parchment
    ..strokeWidth = h * 0.018
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 4; i++) {
    final y = 0.38 + i * 0.075;
    canvas.drawLine(p(0.16, y + 0.012), p(0.42, y - 0.012), linePaint);
    if (i < 3) {
      canvas.drawLine(
        p(0.58, y - 0.012),
        p(0.84 - (i == 2 ? 0.1 : 0), y + 0.012),
        linePaint,
      );
    }
  }

  // Bookmark ribbon on the right page.
  final ribbon = Path()
    ..moveTo(p(0.66, 0.235).dx, p(0.66, 0.235).dy)
    ..lineTo(p(0.74, 0.245).dx, p(0.74, 0.245).dy)
    ..lineTo(p(0.74, 0.56).dx, p(0.74, 0.56).dy)
    ..lineTo(p(0.70, 0.515).dx, p(0.70, 0.515).dy)
    ..lineTo(p(0.66, 0.56).dx, p(0.66, 0.56).dy)
    ..close();
  canvas.drawPath(ribbon, Paint()..color = gold);
}

Future<void> writePng(
  String path,
  int size,
  void Function(Canvas, Size) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(size.toDouble(), size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render branding images', () async {
    const size = 1024;
    final full = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

    // iOS / legacy icon: full-bleed burgundy, no transparency.
    await writePng('assets/branding/icon.png', size, (c, s) {
      c.drawRect(full, Paint()..color = burgundy);
      paintBook(c, full.deflate(size * 0.10));
    });

    // Android adaptive foreground: transparent, motif inside the 66% safe zone.
    await writePng('assets/branding/icon_foreground.png', size, (c, s) {
      paintBook(c, full.deflate(size * 0.22));
    });

    // Splash: burgundy circle with the motif (shown on cream background).
    await writePng('assets/branding/splash.png', size, (c, s) {
      c.drawCircle(full.center, size * 0.40, Paint()..color = burgundy);
      paintBook(c, full.deflate(size * 0.20));
    });

    expect(File('assets/branding/icon.png').existsSync(), isTrue);
  });
}
