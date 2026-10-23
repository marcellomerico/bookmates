import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/reading_stats.dart';
import '../../../models/user_book.dart';
import '../../../repositories/open_library_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';

const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _months = [
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

String greetingFor(DateTime now) => now.hour < 11
    ? 'Guten Morgen'
    : now.hour < 18
    ? 'Hallo'
    : 'Guten Abend';

/// "Donnerstag, 23. Oktober" above the greeting.
String homeDateLabel(DateTime now) =>
    '${_weekdays[now.weekday - 1]}, ${now.day}. ${_months[now.month - 1]}';

/// Fills from 0 on first build; skipped when the system asks for less motion.
class _Grow extends StatelessWidget {
  const _Grow({required this.to, required this.builder});

  final double to;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(context, to);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: to),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Fades and slides a card up, staggered by [index].
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 90),
      curve: Interval(
        math.min(index * 0.15, 0.6),
        1,
        curve: Curves.easeOutBack,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final name = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!.trim().split(' ').first
        : null;
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homeDateLabel(now),
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  name == null
                      ? greetingFor(now)
                      : '${greetingFor(now)}, $name',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 27,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// The book being read with animated progress; nothing when no book is "reading".
class CurrentlyReadingCard extends ConsumerWidget {
  const CurrentlyReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(bookshelfProvider).valueOrNull ?? const [];
    final reading = shelf.where((e) => e.status == BookStatus.reading).toList()
      ..sort(
        (a, b) =>
            (a.shelfPosition ?? 1 << 30).compareTo(b.shelfPosition ?? 1 << 30),
      );
    if (reading.isEmpty) return const SizedBox.shrink();
    final entry = reading.first;
    final book = entry.book;
    final p = context.palette;
    final workId = book?.openLibraryId;
    final progress = entry.progress;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: workId == null
              ? null
              : () => context.push('/books/${normalizeWorkId(workId)}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'home-cover-${entry.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 76,
                      height: 114,
                      child: book?.coverUrl == null
                          ? ColoredBox(color: p.parchment)
                          : CachedNetworkImage(
                              imageUrl: book!.coverUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 228,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LESE ICH GERADE',
                        style: TextStyle(
                          color: p.burgundy,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book?.title ?? 'Buch',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (book?.author != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            book!.author!,
                            style: TextStyle(color: p.muted, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (progress != null) ...[
                        _Grow(
                          to: progress,
                          builder: (context, v) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              color: p.burgundy,
                              backgroundColor: p.parchment,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Seite ${entry.currentPage} von ${entry.pageCount}',
                                style: TextStyle(color: p.muted, fontSize: 12),
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()} %',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          'Trag deine Seite ein, dann siehst du hier deinen Fortschritt.',
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Streak and yearly goal side by side.
class ReadingStatsRow extends ConsumerWidget {
  const ReadingStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats =
        ref.watch(readingStatsProvider).valueOrNull ?? ReadingStats.empty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StreakCard(stats: stats)),
            const SizedBox(width: 12),
            Expanded(child: _GoalCard(stats: stats)),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = stats.streak == 1 ? 'Tag' : 'Tage';
    return Semantics(
      label:
          'Lese-Serie: ${stats.streak} $days in Folge, ${stats.week.where((d) => d).length} der letzten 7 Tage gelesen',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.accentSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: p.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  'LESE-SERIE',
                  style: TextStyle(
                    color: p.onAccentSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Grow(
              to: stats.streak.toDouble(),
              builder: (context, v) => Text.rich(
                TextSpan(
                  text: '${v.round()} ',
                  children: [
                    TextSpan(
                      text: days,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: p.onAccentSurface,
                  height: 1,
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (i, read) in stats.week.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300 + i * 60),
                      height: 6,
                      decoration: BoxDecoration(
                        color: read
                            ? p.gold
                            : p.onAccentSurface.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.stats});

  final ReadingStats stats;

  Future<void> _editGoal(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(initial: stats.goal),
    );
    if (value == null) return;
    try {
      await ref.read(profileRepositoryProvider).setReadingGoal(user.id, value);
      ref.invalidate(readingStatsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final goal = stats.goal;
    final done = stats.finishedThisYear;
    final fraction = goal == null ? 0.0 : (done / goal).clamp(0.0, 1.0);

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editGoal(context, ref),
        child: Semantics(
          button: true,
          label: goal == null
              ? 'Jahresziel festlegen'
              : 'Jahresziel: $done von $goal Büchern',
          hint: goal == null ? null : 'Antippen zum Ändern',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JAHRESZIEL',
                  style: TextStyle(
                    color: p.goldText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Grow(
                      to: fraction,
                      builder: (context, v) => SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: goal == null ? 0 : v,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                color: p.gold,
                                backgroundColor: p.parchment,
                              ),
                            ),
                            Text(
                              '$done',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        goal == null ? 'Ziel festlegen' : 'von $goal Büchern',
                        style: TextStyle(color: p.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.initial});

  final int? initial;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog.adaptive(
    title: const Text('Jahresziel'),
    content: Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: const InputDecoration(labelText: 'Bücher in diesem Jahr'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(
          context,
          int.tryParse(_controller.text)?.clamp(1, 365),
        ),
        child: const Text('Speichern'),
      ),
    ],
  );
}
