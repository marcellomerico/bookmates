import 'package:booksquad/models/user_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every status round-trips through its DB value', () {
    for (final s in BookStatus.values) {
      expect(BookStatus.fromDb(s.dbValue), s);
    }
  });

  test('shelf holds owned books only, wishlist is separate', () {
    expect(BookStatus.shelf, [
      BookStatus.reading,
      BookStatus.unread,
      BookStatus.read,
    ]);
    expect(BookStatus.wantToRead.onShelf, isFalse);
    // Abandoned books are owned but not part of the main shelf.
    expect(BookStatus.abandoned.onShelf, isTrue);
    expect(BookStatus.shelf, isNot(contains(BookStatus.abandoned)));
    expect(BookStatus.shelf.every((s) => s.onShelf), isTrue);
  });

  test('unknown DB value falls back to the wishlist', () {
    expect(BookStatus.fromDb('something_new'), BookStatus.wantToRead);
  });
}
