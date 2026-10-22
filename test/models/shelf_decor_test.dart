import 'package:booksquad/models/shelf_decor.dart';
import 'package:flutter_test/flutter_test.dart';

String _show(List<List<ShelfSlot<String>>> rows) => rows
    .map(
      (r) => r
          .map(
            (s) => switch (s) {
              BookSlot(:final book) => book,
              DecorSlot(:final piece) => piece.item.name[0].toUpperCase(),
              EmptySlot() => '.',
            },
          )
          .join(),
    )
    .join('|');

void main() {
  test('books flow around decoration', () {
    final rows = layoutShelf(
      ['a', 'b', 'c', 'd', 'e'],
      const [
        DecorPiece(DecorItem.plant, 0, 1),
        DecorPiece(DecorItem.cat, 1, 3),
      ],
      cols: 4,
    );
    expect(_show(rows), 'aPbc|de.C');
  });

  test('decoration on a later board adds boards; minRows and extra rows', () {
    expect(
      _show(
        layoutShelf(['a'], const [DecorPiece(DecorItem.mug, 2, 0)], cols: 3),
      ),
      'a..|...|M..',
    );
    expect(
      _show(layoutShelf(<String>[], const [], cols: 2, minRows: 2)),
      '..|..',
    );
    expect(_show(layoutShelf(['a'], const [], cols: 2, extraRows: 1)), 'a.|..');
  });

  test('pieces beyond the column count are hidden, not misplaced', () {
    expect(
      _show(
        layoutShelf(
          ['a', 'b'],
          const [DecorPiece(DecorItem.globe, 0, 5)],
          cols: 4,
        ),
      ),
      'ab..',
    );
  });

  test('json round trip skips unknown or broken entries', () {
    final list = DecorPiece.listFromJson([
      {'i': 'plant', 'r': 0, 's': 2},
      {'i': 'bomb', 'r': 0, 's': 1},
      {'i': 'cat', 'r': 'x', 's': 1},
      'nonsense',
    ]);
    expect(list.single.toJson(), {'i': 'plant', 'r': 0, 's': 2});
    expect(DecorPiece.listFromJson(null), isEmpty);
  });
}
