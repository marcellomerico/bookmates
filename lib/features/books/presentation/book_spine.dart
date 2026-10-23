import 'package:flutter/material.dart';

import '../../../models/user_book.dart';

/// Cloth and leather tones real hardcovers come in.
const _spineColors = [
  Color(0xFF7B3140), // burgundy
  Color(0xFF2F4A3A), // bottle green
  Color(0xFF233B5D), // navy
  Color(0xFF8C5A2B), // tan leather
  Color(0xFF3B3B3B), // charcoal
  Color(0xFFB08A3E), // ochre
  Color(0xFF5C3A5E), // plum
  Color(0xFFC9B79C), // linen
  Color(0xFF6E2A1F), // oxblood
  Color(0xFF4F6B6E), // slate teal
  Color(0xFFE3D5B8), // cream paper
  Color(0xFF1F2A44), // midnight
];

/// Stable per book, so a spine keeps its look between visits.
int _hash(String s) {
  var h = 0;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return h;
}

/// Spine size from the page count (else stable per book): width ~ thickness.
Size spineSize(UserBook entry, double maxHeight) {
  final h = _hash(entry.bookId);
  final pages = entry.pageCount;
  final width = pages != null
      ? (14 + pages / 14).clamp(18.0, 54.0)
      : 22.0 + (h % 20);
  final height = maxHeight * (0.80 + (h % 21) / 100);
  return Size(width.toDouble(), height);
}

/// A book seen from the side, as it stands in a real shelf.
class BookSpine extends StatelessWidget {
  const BookSpine({super.key, required this.entry, required this.size});

  final UserBook entry;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final h = _hash(entry.bookId);
    final base = _spineColors[h % _spineColors.length];
    final light = base.computeLuminance() > 0.45;
    final ink = light ? const Color(0xFF2B2321) : const Color(0xFFE9D9A6);
    final title = entry.book?.title ?? 'Buch';
    final author = entry.book?.author;
    final style = h % 3; // three binding styles: bands, frame, plain
    // The author only shows when it fits whole next to a short title.
    final showAuthor = author != null && size.width >= 26 && title.length <= 16;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        // Rounded spine: dark edges, a soft highlight left of centre.
        gradient: LinearGradient(
          colors: [
            Color.lerp(base, Colors.black, 0.35)!,
            Color.lerp(base, Colors.white, 0.12)!,
            base,
            Color.lerp(base, Colors.black, 0.18)!,
            Color.lerp(base, Colors.black, 0.45)!,
          ],
          stops: const [0, 0.22, 0.5, 0.82, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(1, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (style == 0) ...[
            _Band(top: size.height * 0.07, color: ink),
            _Band(top: size.height * 0.10, color: ink, thin: true),
            _Band(bottom: size.height * 0.10, color: ink, thin: true),
            _Band(bottom: size.height * 0.07, color: ink),
          ],
          if (style == 1)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: size.height * 0.05,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ink.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: size.height * 0.14),
              // German spines read bottom to top.
              child: RotatedBox(
                quarterTurns: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        // One line like a printed spine: long titles shrink instead of being cut.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ink,
                              fontSize: (size.width * 0.42).clamp(9, 14),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SourceSerif4',
                              height: 1.05,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      if (showAuthor) ...[
                        const SizedBox(width: 6),
                        Text(
                          author.split(' ').last.toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.85),
                            fontSize: 7.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({this.top, this.bottom, required this.color, this.thin = false});
  final double? top;
  final double? bottom;
  final Color color;
  final bool thin;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    bottom: bottom,
    left: 2,
    right: 2,
    child: Container(
      height: thin ? 0.8 : 2,
      color: color.withValues(alpha: 0.8),
    ),
  );
}

/// Fills boards left to right by spine width.
List<List<(UserBook, Size)>> spineRows(
  List<UserBook> entries,
  double maxWidth,
  double rowHeight, {
  double gap = 2,
}) {
  final rows = <List<(UserBook, Size)>>[[]];
  var used = 0.0;
  for (final e in entries) {
    final size = spineSize(e, rowHeight);
    if (rows.last.isNotEmpty && used + gap + size.width > maxWidth) {
      rows.add([]);
      used = 0;
    }
    used += (rows.last.isEmpty ? 0 : gap) + size.width;
    rows.last.add((e, size));
  }
  return rows;
}
