import 'package:booksquad/features/books/presentation/daily_suggestion_card.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/books/suggestions.dart';
import 'package:booksquad/models/book.dart';
import 'package:booksquad/repositories/open_library_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FriendPick _friend(String work, String name, int rating) => FriendPick(
  book: Book(id: 'b-$work', title: 'Buch $work', openLibraryId: '/works/$work'),
  friendName: name,
  rating: rating,
);

OpenLibraryBook _ol(String work) =>
    OpenLibraryBook(openLibraryId: work, title: 'Genre $work');

void main() {
  test('friend favourites rank above genre picks, duplicates merged', () {
    final ranked = rankSuggestions(
      friendPicks: [
        _friend('OL1W', 'Jonas', 4),
        _friend('OL2W', 'Lena', 5),
        _friend('OL2W', 'Amir', 4),
      ],
      genreBooks: {
        'Fantasy': [_ol('OL2W'), _ol('OL3W')],
      },
      excludedWorkIds: const {},
    );
    expect([for (final s in ranked) s.workId], ['OL2W', 'OL1W', 'OL3W']);
    expect(ranked.first.reason, 'Lena und 1 weitere lieben es');
    expect(ranked[1].reason, 'Jonas hat es mit 4 Sternen bewertet');
    expect(ranked.last.reason, 'Passt zu deinen Lieblingsgenres');
  });

  test('own and dismissed books are never suggested', () {
    final ranked = rankSuggestions(
      friendPicks: [_friend('OL1W', 'Jonas', 5)],
      genreBooks: {
        'Krimi': [_ol('OL2W'), _ol('OL3W')],
      },
      excludedWorkIds: const {'/works/OL1W', 'OL3W'},
    );
    expect([for (final s in ranked) s.workId], ['OL2W']);
  });

  test('daily pick is stable within a day and varies by reader', () {
    final ranked = rankSuggestions(
      friendPicks: const [],
      genreBooks: {
        'Fantasy': [for (var i = 0; i < 12; i++) _ol('OL${i}W')],
      },
      excludedWorkIds: const {},
    );
    final day = DateTime(2026, 10, 23, 8);
    final a = pickForDay(ranked, day, 'u1');
    expect(pickForDay(ranked, DateTime(2026, 10, 23, 22), 'u1'), same(a));
    expect(ranked.take(10), contains(a));
    final picks = {
      for (var u = 0; u < 20; u++) pickForDay(ranked, day, 'u$u')!.workId,
    };
    expect(picks.length, greaterThan(1));
    expect(pickForDay(const [], day, 'u1'), isNull);
  });

  test('friends\' favourites win the daily pick when there are any', () {
    final ranked = rankSuggestions(
      friendPicks: [_friend('OL1W', 'Jonas', 4)],
      genreBooks: {
        'Fantasy': [for (var i = 2; i < 12; i++) _ol('OL${i}W')],
      },
      excludedWorkIds: const {},
    );
    for (var u = 0; u < 10; u++) {
      expect(pickForDay(ranked, DateTime(2026, 10, 23), 'u$u')!.workId, 'OL1W');
    }
  });

  testWidgets('card shows the pick with reason and actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailySuggestionProvider.overrideWith(
            (ref) async => BookSuggestion(
              book: _ol('OL9W'),
              reason: 'Weil du Fantasy magst',
              score: 50,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DailySuggestionCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEIN BUCH DES TAGES'), findsOneWidget);
    expect(find.text('Genre OL9W'), findsOneWidget);
    expect(find.text('Weil du Fantasy magst'), findsOneWidget);
    expect(find.text('Auf die Wunschliste'), findsOneWidget);
    expect(find.byTooltip('Kein Interesse'), findsOneWidget);
  });

  testWidgets('no pick, no card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dailySuggestionProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(home: Scaffold(body: DailySuggestionCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEIN BUCH DES TAGES'), findsNothing);
  });
}
