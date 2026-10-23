import 'package:booksquad/features/books/presentation/book_spine.dart';
import 'package:booksquad/features/books/presentation/visual_shelf.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/models/book.dart';
import 'package:booksquad/models/user_book.dart';
import 'package:booksquad/repositories/book_repository.dart';
import '../../helpers/auth_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserBook _entry(
  String id,
  String title,
  BookStatus status, {
  int? current,
  int? total,
}) => UserBook(
  id: id,
  userId: 'me',
  bookId: 'b-$id',
  status: status,
  currentPage: current,
  pageCount: total,
  // No cover URL: the title fallback renders without network.
  book: Book(id: 'b-$id', title: title, openLibraryId: 'OL${id}W'),
);

final _entries = [
  _entry('1', 'Gerade dran', BookStatus.reading, current: 50, total: 200),
  _entry('2', 'Wartet noch', BookStatus.unread),
  _entry('3', 'Schon durch', BookStatus.read, current: 300, total: 300),
  _entry('4', 'Noch ein durch', BookStatus.read),
  _entry('5', 'Hätte ich gern', BookStatus.wantToRead),
  _entry('6', 'Aufgegeben', BookStatus.abandoned),
];

class _FakeBooks extends BookRepository {
  _FakeBooks() : super(offlineClient());
  List<String>? saved;

  @override
  Future<void> reorderShelf(List<String> userBookIds) async =>
      saved = userBookIds;

  @override
  Future<List<UserBook>> getBookshelf(String userId) async => _entries;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  BookRepository? books,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookshelfProvider.overrideWith((ref) async => _entries),
        if (books != null) bookRepositoryProvider.overrideWithValue(books),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shelf shows owned books only, with counts per status', (
    tester,
  ) async {
    await _pump(tester, const ShelfView());
    expect(find.text('Alle  4'), findsOneWidget);
    expect(find.text('Lese ich  1'), findsOneWidget);
    expect(find.text('Ungelesen  1'), findsOneWidget);
    expect(find.text('Gelesen  2'), findsOneWidget);
    expect(find.text('Gerade dran'), findsOneWidget);
    expect(find.text('Hätte ich gern'), findsNothing);
  });

  testWidgets('filter narrows the shelf', (tester) async {
    await _pump(tester, const ShelfView());
    await tester.ensureVisible(find.text('Gelesen  2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelesen  2'));
    await tester.pumpAndSettle();
    expect(find.text('Schon durch'), findsOneWidget);
    expect(find.text('Noch ein durch'), findsOneWidget);
    expect(find.text('Gerade dran'), findsNothing);
  });

  testWidgets('wishlist shows only wished books', (tester) async {
    await _pump(tester, const WishlistView());
    // Title appears on the fallback cover and as caption.
    expect(find.text('Hätte ich gern'), findsWidgets);
    expect(find.text('Gerade dran'), findsNothing);
  });

  testWidgets('books being read show their progress on the cover', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const ShelfView());
    // Only the "reading" book gets a bar; finished books don't.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Gerade dran.*25 Prozent gelesen')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('abandoned books sit collapsed below the shelf', (tester) async {
    await _pump(tester, const ShelfView());
    // Not counted on the main shelf.
    expect(find.text('Alle  4'), findsOneWidget);
    expect(find.text('Abgebrochen  1'), findsOneWidget);
    expect(find.text('Aufgegeben'), findsNothing);
    await tester.ensureVisible(find.text('Abgebrochen  1'));
    await tester.tap(find.text('Abgebrochen  1'));
    await tester.pumpAndSettle();
    expect(find.text('Aufgegeben'), findsOneWidget);
  });

  testWidgets('books arrive animated, but not with reduced motion', (
    tester,
  ) async {
    await _pump(tester, const ShelfView());
    expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);

    await _pump(
      tester,
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: ShelfView(),
      ),
    );
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.text('Gerade dran'), findsOneWidget);
  });

  test('moveEntry puts a book where another one stands', () {
    final ids = [for (final e in moveEntry(_entries, '3', '1')) e.id];
    expect(ids, ['3', '1', '2', '4', '5', '6']);
    expect(identical(moveEntry(_entries, '1', '1'), _entries), isTrue);
  });

  testWidgets('sorting: drag a cover onto another saves the new order', (
    tester,
  ) async {
    final books = _FakeBooks();
    await _pump(tester, const ShelfView(), books: books);
    await tester.ensureVisible(find.text('Sortieren'));
    await tester.tap(find.text('Sortieren'));
    await tester.pumpAndSettle();
    expect(find.text('Fertig'), findsOneWidget);
    expect(find.text('Alle  4'), findsNothing);

    final from = tester.getCenter(find.text('Schon durch'));
    final to = tester.getCenter(find.text('Gerade dran'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(books.saved, ['3', '1', '2', '4']);
  });

  testWidgets('spine view shows books from the side', (tester) async {
    await _pump(tester, const ShelfView());
    expect(find.byType(BookSpine), findsNothing);
    await tester.tap(find.byTooltip('Buchrücken-Ansicht'));
    await tester.pumpAndSettle();
    expect(find.byType(BookSpine), findsNWidgets(4));
    // Title printed on the spine, readable by screen readers via the tile label.
    expect(find.text('Gerade dran'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Schon durch')), findsOneWidget);
  });

  test('thicker books get wider spines, sizes stay stable per book', () {
    UserBook e(int? pages) => UserBook(
      id: 'x',
      userId: 'me',
      bookId: 'b-same',
      status: BookStatus.read,
      pageCount: pages,
    );
    expect(
      spineSize(e(800), 100).width,
      greaterThan(spineSize(e(150), 100).width),
    );
    expect(spineSize(e(null), 100), spineSize(e(null), 100));
    expect(spineSize(e(null), 100).height, inInclusiveRange(80, 100));
  });
}
