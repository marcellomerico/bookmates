// Renders store marketing images and the README hero from docs/screenshots.
// Run: flutter test tool/branding/render_store_shots_test.dart
// Output: docs/store/*.png (1320x2868, App Store 6.9") and docs/screenshots/hero.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const burgundy = Color(0xFF7B3140);
const burgundyDark = Color(0xFF5E2330);
const cream = Color(0xFFF7F2E8);
const gold = Color(0xFFC7A64B);

const shots = [
  ('01-feed', 'Sieh, was deine\nFreunde lesen'),
  ('09-regal', 'Dein Regal füllt\nsich mit jedem Buch'),
  ('03-buch', 'Alles zu einem Buch\nauf einen Blick'),
  ('06-lesekreis', 'Lesekreise für\njedes Genre'),
  ('16-wunschliste', 'Wünsche getrennt\nvom Regal'),
  ('04-entdecken', 'Finde Menschen mit\ndeinem Geschmack'),
];

Future<ui.Image> load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// Screenshot with rounded corners, a thin dark bezel and a soft shadow.
void paintPhone(Canvas c, ui.Image shot, Rect r) {
  final radius = Radius.circular(r.width * 0.11);
  final outer = RRect.fromRectAndRadius(r.inflate(r.width * 0.018), radius);
  c.drawRRect(
    outer.shift(Offset(0, r.width * 0.03)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.width * 0.04),
  );
  c.drawRRect(outer, Paint()..color = const Color(0xFF1B1416));
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(r, radius));
  c.drawImageRect(
    shot,
    Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
    r,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}

void paintText(Canvas c, String text, Offset center, double size, Color color, {double maxWidth = 1200}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'SourceSerif4', fontSize: size, height: 1.12, color: color, fontWeight: FontWeight.w700),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(c, center - Offset(tp.width / 2, 0));
}

Future<void> save(ui.Picture picture, int w, int h, String path) async {
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render store images', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('SourceSerif4')
        ..addFont(rootBundle.load('assets/fonts/SourceSerif4-Variable.ttf'));
      await font.load();

      const w = 1320, h = 2868;
      for (final (name, caption) in shots) {
        final shot = await load('docs/screenshots/$name.png');
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, 1320, 2868),
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 2868), [burgundy, burgundyDark]),
        );
        c.drawRect(const Rect.fromLTWH(560, 150, 200, 8), Paint()..color = gold);
        paintText(c, caption, const Offset(660, 220), 112, cream);
        const phoneW = 1000.0;
        final phoneH = phoneW * shot.height / shot.width;
        paintPhone(c, shot, Rect.fromLTWH((w - phoneW) / 2, 640, phoneW, phoneH));
        await save(rec.endRecording(), w, h, 'docs/store/$name.png');
      }

      // README hero: three phones on cream.
      const hw = 2400, hh = 1500;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, 2400, 1500), Paint()..color = cream);
      final names = ['08-profil', '01-feed', '03-buch'];
      const pw = 560.0;
      for (var i = 0; i < 3; i++) {
        final shot = await load('docs/screenshots/${names[i]}.png');
        final ph = pw * shot.height / shot.width;
        final x = hw / 2 - pw / 2 + (i - 1) * 680.0;
        final y = i == 1 ? 120.0 : 220.0;
        paintPhone(c, shot, Rect.fromLTWH(x, y, pw, ph));
      }
      await save(rec.endRecording(), hw, hh, 'docs/screenshots/hero.png');
    });
    expect(File('docs/store/01-feed.png').existsSync(), isTrue);
  });
}
