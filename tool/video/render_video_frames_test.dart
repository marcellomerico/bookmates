// Renders the still layers for the teaser video (1080x1920).
// Run: flutter test tool/video/render_video_frames_test.dart
// Output: build/teaser/{frame,caption-*,intro,outro}.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const w = 1080.0, h = 1920.0;
const burgundy = Color(0xFF7B3140);
const burgundyDark = Color(0xFF5E2330);
const cream = Color(0xFFF7F2E8);
const gold = Color(0xFFC7A64B);

/// Screen area inside the frame; build_teaser.py places the recordings here.
const screen = Rect.fromLTWH(180, 300, 720, 1565);
const out = 'build/teaser';

const captions = {
  'feed': 'Sieh, was deine\nFreunde lesen',
  'shelf': 'Dein Regal füllt\nsich mit jedem Buch',
  'book': 'Ein Tipp – und es\nsteht im Regal',
  'circle': 'Lesekreise für\njedes Genre',
};

void background(Canvas c) => c.drawRect(
  const Rect.fromLTWH(0, 0, w, h),
  Paint()
    ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [
      burgundy,
      burgundyDark,
    ]),
);

void text(
  Canvas c,
  String s,
  double y,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
  double spacing = 0,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'SourceSerif4',
        fontSize: size,
        height: 1.1,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w - 120);
  tp.paint(c, Offset((w - tp.width) / 2, y));
}

Future<void> save(void Function(Canvas) paint, String name) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<ui.Image> load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets('render teaser frames', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader(
            'SourceSerif4',
          )..addFont(rootBundle.load('assets/fonts/SourceSerif4-Variable.ttf')))
          .load();
      final icon = await load('assets/branding/icon.png');

      // Frame: background with a phone bezel and a transparent screen.
      await save((c) {
        c.saveLayer(const Rect.fromLTWH(0, 0, w, h), Paint());
        background(c);
        final radius = Radius.circular(screen.width * 0.11);
        final bezel = RRect.fromRectAndRadius(screen.inflate(14), radius);
        c.drawRRect(
          bezel.shift(const Offset(0, 22)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
        );
        c.drawRRect(bezel, Paint()..color = const Color(0xFF1B1416));
        c.drawRRect(
          RRect.fromRectAndRadius(screen, radius),
          Paint()..blendMode = BlendMode.clear,
        );
        c.restore();
      }, 'frame');

      for (final e in captions.entries) {
        await save((c) {
          c.drawRect(
            const Rect.fromLTWH(490, 70, 100, 6),
            Paint()..color = gold,
          );
          text(c, e.value, 100, 78, cream);
        }, 'caption-${e.key}');
      }

      void logo(Canvas c, double y, double size) {
        final r = Rect.fromCenter(
          center: Offset(w / 2, y),
          width: size,
          height: size,
        );
        c.save();
        c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(size * 0.22)));
        c.drawImageRect(
          icon,
          Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
          r,
          Paint()..filterQuality = FilterQuality.high,
        );
        c.restore();
      }

      await save((c) {
        background(c);
        logo(c, 820, 360);
        text(c, 'Booksquad', 1060, 120, cream);
      }, 'intro');

      await save((c) {
        background(c);
        logo(c, 700, 300);
        text(c, 'Booksquad', 900, 130, cream);
        text(c, 'Lesen mit Freunden', 1060, 64, gold, weight: FontWeight.w500);
        c.drawRect(
          const Rect.fromLTWH(490, 1200, 100, 5),
          Paint()..color = gold,
        );
        text(
          c,
          'Bald im App Store\nund bei Google Play',
          1250,
          50,
          cream,
          weight: FontWeight.w400,
        );
      }, 'outro');
    });
    expect(File('$out/frame.png').existsSync(), isTrue);
  });
}
