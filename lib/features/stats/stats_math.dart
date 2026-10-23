/// Pure helpers for the statistics screen.
///
/// Days are calendar dates kept as UTC midnight, so adding days never trips over
/// daylight saving (25 October has 25 local hours).
library;

DateTime dayOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime _plusDays(DateTime d, int n) =>
    DateTime.utc(d.year, d.month, d.day + n);

/// Longest run of consecutive days in [days].
int longestStreak(Iterable<DateTime> days) {
  final sorted = days.map(dayOnly).toSet().toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = prev != null && d.difference(prev).inDays == 1 ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) => _plusDays(d, 1 - d.weekday);

/// Pages for each day Monday..Sunday of the week containing [today].
List<int> pagesThisWeek(Map<DateTime, int> pages, DateTime today) {
  final start = weekStart(today);
  return [for (var i = 0; i < 7; i++) pages[_plusDays(start, i)] ?? 0];
}

/// Pages per calendar week touching [today]'s month: (ISO week number, pages).
List<(int, int)> pagesPerWeekOfMonth(Map<DateTime, int> pages, DateTime today) {
  final first = DateTime.utc(today.year, today.month);
  final last = DateTime.utc(today.year, today.month + 1, 0);
  final result = <(int, int)>[];
  for (var w = weekStart(first); !w.isAfter(last); w = _plusDays(w, 7)) {
    var sum = 0;
    for (var i = 0; i < 7; i++) {
      final d = _plusDays(w, i);
      if (d.month == today.month) sum += pages[d] ?? 0;
    }
    result.add((isoWeek(w), sum));
  }
  return result;
}

int isoWeek(DateTime d) {
  final thursday = _plusDays(d, 4 - d.weekday);
  final firstThursday = DateTime.utc(thursday.year, 1, 4);
  return 1 + thursday.difference(weekStart(firstThursday)).inDays ~/ 7;
}

/// Books finished in each month (Jan..Dec) of [year].
List<int> booksPerMonth(Iterable<DateTime> finished, int year) {
  final counts = List.filled(12, 0);
  for (final d in finished) {
    if (d.year == year) counts[d.month - 1]++;
  }
  return counts;
}
