import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../../../models/reading_stats.dart';
import '../../../models/user_book.dart';
import '../../books/providers/books_provider.dart';
import '../stats_math.dart';

enum _Period { week, month, year }

const _weekdayShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _monthShort = [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];
const _monthNames = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(readingDaysProvider).valueOrNull ?? const {};
    final shelf = ref.watch(bookshelfProvider).valueOrNull ?? const [];
    final stats =
        ref.watch(readingStatsProvider).valueOrNull ?? ReadingStats.empty;
    final today = dayOnly(DateTime.now());
    final finished = [
      for (final e in shelf)
        if (e.status == BookStatus.read && e.finishedAt != null)
          dayOnly(e.finishedAt!),
    ];

    final from = switch (_period) {
      _Period.week => weekStart(today),
      _Period.month => DateTime.utc(today.year, today.month),
      _Period.year => DateTime.utc(today.year),
    };
    bool inPeriod(DateTime d) => !d.isBefore(from) && !d.isAfter(today);
    final pages = days.entries
        .where((e) => inPeriod(e.key))
        .fold<int>(0, (sum, e) => sum + e.value);
    final books = finished.where(inPeriod).length;
    final elapsed = today.difference(from).inDays + 1;

    final (chartTitle, values, labels, highlight) = switch (_period) {
      _Period.week => (
        'Seiten pro Tag',
        pagesThisWeek(days, today),
        _weekdayShort,
        today.weekday - 1,
      ),
      _Period.month => () {
        final weeks = pagesPerWeekOfMonth(days, today);
        return (
          'Seiten pro Woche',
          [for (final w in weeks) w.$2],
          [for (final w in weeks) 'KW ${w.$1}'],
          weeks.indexWhere((w) => w.$1 == isoWeek(today)),
        );
      }(),
      _Period.year => (
        'Bücher pro Monat',
        booksPerMonth(finished, today.year),
        _monthShort,
        today.month - 1,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Dein Lesejahr')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bookshelfProvider);
          await ref.read(readingDaysProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.week, label: Text('Woche')),
                ButtonSegment(value: _Period.month, label: Text('Monat')),
                ButtonSegment(value: _Period.year, label: Text('Jahr')),
              ],
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 14),
            Reveal(
              key: ValueKey('kpi-$_period'),
              index: 0,
              child: Row(
                children: [
                  Expanded(
                    child: _Kpi(value: pages, label: 'Seiten'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Kpi(
                      value: books,
                      label: books == 1 ? 'Buch' : 'Bücher',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Kpi(
                      value: (pages / elapsed).round(),
                      label: 'Seiten/Tag',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              key: ValueKey('chart-$_period'),
              index: 1,
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chartTitle, style: _cardTitle(context)),
                    const SizedBox(height: 14),
                    _BarChart(
                      values: values,
                      labels: labels,
                      highlight: highlight,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              index: 2,
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesetage im ${_monthNames[today.month - 1]}',
                      style: _cardTitle(context),
                    ),
                    const SizedBox(height: 12),
                    _MonthHeatmap(pages: days, today: today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              index: 3,
              child: Row(
                children: [
                  Expanded(
                    child: _Kpi(value: stats.streak, label: 'Tage Serie jetzt'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Kpi(
                      value: math.max(longestStreak(days.keys), stats.streak),
                      label: 'Längste Serie',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle? _cardTitle(BuildContext context) => Theme.of(
  context,
).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    excludeSemantics: true,
    child: SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountUp(value: value),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

/// Number that counts up from 0 on first build.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium;
    String fmt(int v) => v >= 1000
        ? '${v ~/ 1000}.${(v % 1000).toString().padLeft(3, '0')}'
        : '$v';
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(fmt(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(fmt(v.round()), style: style),
    );
  }
}

/// Bars grow from the baseline, staggered left to right; [highlight] is "now".
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.highlight,
  });

  final List<int> values;
  final List<String> labels;
  final int highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxV = values.fold<int>(0, math.max);
    final still = MediaQuery.disableAnimationsOf(context);
    const chartHeight = 130.0;

    return Semantics(
      label: [
        for (var i = 0; i < values.length; i++) '${labels[i]}: ${values[i]}',
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: chartHeight + 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) SizedBox(width: values.length > 8 ? 6 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (i == highlight && values[i] > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${values[i]}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: still ? 1 : 0, end: 1),
                      duration: Duration(milliseconds: 500 + i * 70),
                      curve: Curves.easeOutBack,
                      builder: (context, t, _) => Container(
                        height: math.max(
                          4,
                          // Headroom for the value label and the spring overshoot.
                          maxV == 0
                              ? 4
                              : (chartHeight - 24) * values[i] / maxV * t,
                        ),
                        decoration: BoxDecoration(
                          color: i == highlight ? p.burgundy : p.parchment,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(color: p.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Month calendar, darker gold the more pages were read that day.
class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({required this.pages, required this.today});

  final Map<DateTime, int> pages;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = DateTime.utc(today.year, today.month);
    final daysInMonth = DateTime.utc(today.year, today.month + 1, 0).day;
    final lead = first.weekday - 1;
    final monthPages = [
      for (var d = 1; d <= daysInMonth; d++)
        pages[DateTime.utc(today.year, today.month, d)] ?? 0,
    ];
    final maxP = monthPages.fold<int>(0, math.max);
    final readDays = monthPages.where((v) => v > 0).length;

    Color shade(int v) {
      if (v == 0) return p.parchment.withValues(alpha: 0.55);
      final t = maxP == 0 ? 1.0 : v / maxP;
      return Color.lerp(Color.lerp(p.parchment, p.gold, 0.45)!, p.goldText, t)!;
    }

    return Semantics(
      label: 'An $readDays von ${today.day} Tagen gelesen',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _weekdayShort)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(color: p.muted, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                d > today.day
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.line),
                        ),
                      )
                    : AnimatedContainer(
                        duration: Duration(milliseconds: 200 + d * 12),
                        decoration: BoxDecoration(
                          color: shade(monthPages[d - 1]),
                          borderRadius: BorderRadius.circular(8),
                          border: d == today.day
                              ? Border.all(color: p.burgundy, width: 2)
                              : null,
                        ),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}
