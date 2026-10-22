import 'package:booksquad/features/books/presentation/visual_shelf.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/models/book.dart';
import 'package:booksquad/models/user_book.dart';
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

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [bookshelfProvider.overrideWith((ref) async => _entries)],
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
}
