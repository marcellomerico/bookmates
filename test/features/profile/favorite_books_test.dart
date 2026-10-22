import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/profile/presentation/favorite_books.dart';
import 'package:booksquad/models/book.dart';
import 'package:booksquad/models/user_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserBook _e(String id, BookStatus status, {int? rank}) => UserBook(
  id: id,
  userId: 'me',
  bookId: 'b$id',
  status: status,
  favoriteRank: rank,
  book: Book(id: 'b$id', title: 'Buch $id', openLibraryId: 'OL${id}W'),
);

Future<void> _pump(WidgetTester tester, List<UserBook> shelf) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [bookshelfProvider.overrideWith((ref) async => shelf)],
      child: const MaterialApp(home: Scaffold(body: FavoriteBooks())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('favourites come out in rank order', () {
    final list = favoriteBooks([
      _e('1', BookStatus.read, rank: 2),
      _e('2', BookStatus.read),
      _e('3', BookStatus.read, rank: 1),
    ]);
    expect([for (final e in list) e.id], ['3', '1']);
  });

  testWidgets('own profile shows favourites in order', (tester) async {
    await _pump(tester, [
      _e('1', BookStatus.read, rank: 2),
      _e('2', BookStatus.read, rank: 1),
      _e('3', BookStatus.read),
    ]);
    expect(find.text('Meine Empfehlungen'), findsOneWidget);
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .where((l) => l.startsWith('Empfehlung:'))
        .toList();
    expect(labels, ['Empfehlung: Buch 2', 'Empfehlung: Buch 1']);
  });

  testWidgets('without favourites, own profile offers to pick', (tester) async {
    await _pump(tester, [_e('1', BookStatus.read)]);
    expect(find.text('Lieblingsbücher auswählen'), findsOneWidget);
  });

  testWidgets('nothing read yet, nothing shown', (tester) async {
    await _pump(tester, [_e('1', BookStatus.reading)]);
    expect(find.text('Lieblingsbücher auswählen'), findsNothing);
    expect(find.text('Meine Empfehlungen'), findsNothing);
  });

  testWidgets('picker allows at most three books', (tester) async {
    List<String>? result;
    final books = [for (var i = 1; i <= 4; i++) _e('$i', BookStatus.read)];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showModalBottomSheet(
              context: context,
              builder: (_) =>
                  FavoritePicker(readBooks: books, initial: const []),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 4; i++) {
      await tester.tap(find.text('Buch $i'));
      await tester.pump();
    }
    expect(find.text('Aus deinen gelesenen Büchern · 3 von 3'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(result, ['1', '2', '3']);
  });
}
