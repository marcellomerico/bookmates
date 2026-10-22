import 'package:booksquad/features/books/presentation/book_detail_screen.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/social/providers/paged_posts.dart';
import 'package:booksquad/models/book.dart';
import 'package:booksquad/models/user_book.dart';
import 'package:booksquad/repositories/open_library_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required Book? book, int readers = 0, UserBook? entry}) =>
    ProviderScope(
      overrides: [
        openLibraryWorkProvider('OL1W').overrideWith(
          (ref) async => const OpenLibraryWork(
            id: 'OL1W',
            title: 'Testbuch',
            description: 'Eine schöne Beschreibung.',
            subjects: ['Fantasy'],
          ),
        ),
        bookByWorkIdProvider('OL1W').overrideWith((ref) async => book),
        bookReaderCountProvider('b1').overrideWith((ref) async => readers),
        myShelfEntryProvider('b1').overrideWith((ref) async => entry),
        pagedPostsProvider.overrideWith(_EmptyPosts.new),
      ],
      child: const MaterialApp(home: BookDetailScreen(workId: 'OL1W')),
    );

class _EmptyPosts extends PagedPostsNotifier {
  @override
  Future<PagedPosts> build(PostSource arg) async =>
      const PagedPosts(items: [], hasMore: false);
}

void main() {
  testWidgets('shows work data, zero readers and empty posts', (tester) async {
    await tester.pumpWidget(
      _app(
        book: const Book(id: 'b1', title: 'Testbuch', author: 'Autor'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Testbuch'), findsOneWidget);
    expect(find.text('Eine schöne Beschreibung.'), findsOneWidget);
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.text('Autor'), findsOneWidget);
    expect(find.text('Noch niemand hat es im Regal'), findsOneWidget);
    expect(find.text('Noch keine Beiträge zu diesem Buch'), findsOneWidget);
  });

  testWidgets('shows reader count', (tester) async {
    await tester.pumpWidget(
      _app(
        book: const Book(id: 'b1', title: 'Testbuch'),
        readers: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 Leser haben es im Regal'), findsOneWidget);
  });

  testWidgets('without DB book hides readers and posts', (tester) async {
    await tester.pumpWidget(_app(book: null));
    await tester.pumpAndSettle();
    expect(find.text('Testbuch'), findsOneWidget);
    expect(find.textContaining('Leser haben'), findsNothing);
    expect(find.text('Beiträge zu diesem Buch'), findsNothing);
    // Not on the shelf yet: offer both destinations.
    expect(find.text('Ins Regal'), findsOneWidget);
    expect(find.text('Wunschliste'), findsOneWidget);
  });

  UserBook entry(BookStatus status, {int? current, int? total}) => UserBook(
    id: 'ub1',
    userId: 'u1',
    bookId: 'b1',
    status: status,
    currentPage: current,
    pageCount: total,
  );

  testWidgets('shelf entry shows reading progress with bar', (tester) async {
    await tester.pumpWidget(
      _app(
        book: const Book(id: 'b1', title: 'Testbuch'),
        entry: entry(BookStatus.reading, current: 187, total: 320),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seite 187 von 320 · 58 %'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shelf entry without pages invites to add progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        book: const Book(id: 'b1', title: 'Testbuch'),
        entry: entry(BookStatus.unread),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lesefortschritt eintragen'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('wishlist entry has no progress', (tester) async {
    await tester.pumpWidget(
      _app(
        book: const Book(id: 'b1', title: 'Testbuch'),
        entry: entry(BookStatus.wantToRead, current: 3, total: 10),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lesefortschritt eintragen'), findsNothing);
    expect(find.textContaining('Seite'), findsNothing);
  });
}
