import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/stats/presentation/stats_screen.dart';
import 'package:booksquad/features/stats/stats_math.dart';
import 'package:booksquad/models/reading_stats.dart';
import 'package:booksquad/models/user_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  test('longest streak finds the longest consecutive run', () {
    final days = [
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 2),
      DateTime.utc(2026, 10, 5),
      DateTime.utc(2026, 10, 6),
      DateTime.utc(2026, 10, 7),
      DateTime.utc(2026, 10, 7, 20),
    ];
    expect(longestStreak(days), 3);
    expect(longestStreak(const []), 0);
    // Across the end of daylight saving (25 Oct has 25 hours).
    expect(
      longestStreak([
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
      ]),
      3,
    );
  });

  test('week, month and year buckets', () {
    final today = DateTime.utc(2026, 10, 23); // Friday
    final pages = {
      DateTime.utc(2026, 10, 19): 10, // Monday
      DateTime.utc(2026, 10, 23): 30,
      DateTime.utc(2026, 10, 1): 5,
    };
    expect(pagesThisWeek(pages, today), [10, 0, 0, 0, 30, 0, 0]);
    final weeks = pagesPerWeekOfMonth(pages, today);
    expect(weeks.first, (40, 5));
    expect(weeks.firstWhere((w) => w.$1 == 43).$2, 40);
    expect([for (final w in weeks) w.$1], [40, 41, 42, 43, 44]);
    expect(isoWeek(DateTime.utc(2026, 1, 1)), 1);
    expect(
      booksPerMonth([
        DateTime.utc(2026, 3, 2),
        DateTime.utc(2026, 3, 9),
        DateTime.utc(2025, 3, 1),
      ], 2026)[2],
      2,
    );
  });

  testWidgets('stats screen shows totals and switches period', (tester) async {
    final today = DateTime.now();
    final d = DateTime.utc(today.year, today.month, today.day);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(testUser('me')),
          readingDaysProvider.overrideWith((ref) async => {d: 42}),
          bookshelfProvider.overrideWith(
            (ref) async => [
              UserBook(
                id: 'ub',
                userId: 'me',
                bookId: 'b',
                status: BookStatus.read,
                finishedAt: d,
              ),
            ],
          ),
          readingStatsProvider.overrideWith(
            (ref) async => const ReadingStats(
              streak: 1,
              week: [false, false, false, false, false, false, true],
              finishedThisYear: 1,
            ),
          ),
        ],
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('42 Seiten')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1 Buch')), findsOneWidget);

    await tester.tap(find.text('Jahr'));
    await tester.pumpAndSettle();
    expect(find.text('Bücher pro Monat'), findsOneWidget);
  });
}
