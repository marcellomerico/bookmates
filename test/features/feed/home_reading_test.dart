import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/feed/presentation/home_reading.dart';
import 'package:booksquad/models/book.dart';
import 'package:booksquad/models/reading_stats.dart';
import 'package:booksquad/models/user_book.dart';
import 'package:booksquad/repositories/book_repository.dart';
import 'package:booksquad/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeBooks extends BookRepository {
  _FakeBooks(this.stats) : super(offlineClient());
  ReadingStats stats;

  @override
  Future<ReadingStats> getReadingStats() async => stats;
}

class _FakeProfiles extends ProfileRepository {
  _FakeProfiles() : super(offlineClient());
  final goals = <int?>[];

  @override
  Future<void> setReadingGoal(String userId, int? goal) async =>
      goals.add(goal);
}

const _reading = UserBook(
  id: 'ub1',
  userId: 'me',
  bookId: 'b1',
  status: BookStatus.reading,
  pageCount: 320,
  currentPage: 160,
  book: Book(id: 'b1', title: 'Die Mitternachtsbibliothek', author: 'Matt Haig'),
);

Future<_FakeProfiles> _pump(
  WidgetTester tester,
  Widget child,
  ReadingStats stats,
) async {
  final profiles = _FakeProfiles();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(testUser('me')),
        bookshelfProvider.overrideWith((ref) async => [_reading]),
        bookRepositoryProvider.overrideWithValue(_FakeBooks(stats)),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return profiles;
}

void main() {
  test('stats parse the RPC row', () {
    final s = ReadingStats.fromJson({
      'streak': 3,
      'week': [false, false, false, false, true, true, true],
      'finished_this_year': 5,
      'goal': 20,
    });
    expect((s.streak, s.week.last, s.finishedThisYear, s.goal), (3, true, 5, 20));
  });

  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 10, 23, 8)), 'Guten Morgen');
    expect(greetingFor(DateTime(2026, 10, 23, 14)), 'Hallo');
    expect(greetingFor(DateTime(2026, 10, 23, 21)), 'Guten Abend');
    expect(homeDateLabel(DateTime(2026, 10, 23)), 'Freitag, 23. Oktober');
  });

  testWidgets('currently reading shows title and progress', (tester) async {
    await _pump(tester, const CurrentlyReadingCard(), ReadingStats.empty);
    expect(find.text('Die Mitternachtsbibliothek'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('Seite 160 von 320'), findsOneWidget);
  });

  testWidgets('streak and goal, goal can be set', (tester) async {
    final profiles = await _pump(
      tester,
      const ReadingStatsRow(),
      const ReadingStats(
        streak: 4,
        week: [false, false, false, true, true, true, true],
        finishedThisYear: 2,
      ),
    );
    expect(find.bySemanticsLabel(RegExp('4 Tage in Folge')), findsOneWidget);
    expect(find.text('Ziel festlegen'), findsOneWidget);

    await tester.tap(find.text('Ziel festlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '24');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(profiles.goals, [24]);
  });
}
