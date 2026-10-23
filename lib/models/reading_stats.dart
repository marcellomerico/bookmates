/// Home numbers from `my_reading_stats`: streak, last 7 days and the yearly goal.
class ReadingStats {
  const ReadingStats({
    required this.streak,
    required this.week,
    required this.finishedThisYear,
    this.goal,
  });

  final int streak;

  /// Read on each of the last 7 days, oldest first (today last).
  final List<bool> week;
  final int finishedThisYear;
  final int? goal;

  static const empty = ReadingStats(
    streak: 0,
    week: [false, false, false, false, false, false, false],
    finishedThisYear: 0,
  );

  factory ReadingStats.fromJson(Map<String, dynamic> json) => ReadingStats(
    streak: json['streak'] as int? ?? 0,
    week: [for (final d in json['week'] as List? ?? const []) d == true],
    finishedThisYear: json['finished_this_year'] as int? ?? 0,
    goal: json['goal'] as int?,
  );
}
