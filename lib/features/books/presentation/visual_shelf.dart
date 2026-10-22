import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/user_book.dart';
import '../../../repositories/open_library_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/books_provider.dart';
import 'book_status_sheet.dart';

/// Shelf wood: a warm light board with a darker front edge.
const _boardTop = Color(0xFFE6D3B1);
const _boardEdge = Color(0xFFC9AC80);
const _shelfBack = Color(0xFFF1E7D6);

AsyncValue<List<UserBook>> _entries(WidgetRef ref, String? userId) =>
    userId == null
    ? ref.watch(bookshelfProvider)
    : ref.watch(bookshelfByUserProvider(userId));

void _retry(WidgetRef ref, String? userId) => userId == null
    ? ref.invalidate(bookshelfProvider)
    : ref.invalidate(bookshelfByUserProvider(userId));

/// The user's books on wooden shelves, filterable by reading / unread / read.
/// [userId] null = own shelf (editable), otherwise read-only.
class ShelfView extends ConsumerStatefulWidget {
  const ShelfView({super.key, this.userId, this.compact = false});

  final String? userId;

  /// Onboarding preview: every book (shelf and wishlist), no filters.
  final bool compact;

  @override
  ConsumerState<ShelfView> createState() => _ShelfViewState();
}

class _ShelfViewState extends ConsumerState<ShelfView> {
  BookStatus? _filter; // null = all shelf statuses
  bool _sorting = false;
  List<UserBook>? _ordered; // optimistic order while saving

  Future<void> _move(List<UserBook> shelf, String fromId, String toId) async {
    final next = moveEntry(_ordered ?? shelf, fromId, toId);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ordered = next);
    try {
      await ref.read(bookRepositoryProvider).reorderShelf([
        for (final e in next) e.id,
      ]);
      ref.invalidate(bookshelfProvider);
      await ref.read(bookshelfProvider.future);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Reihenfolge konnte nicht gespeichert werden.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _ordered = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final own = widget.userId == null;
    return _entries(ref, widget.userId).when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ErrorState(
        message: 'Bücherregal konnte nicht geladen werden.',
        onRetry: () => _retry(ref, widget.userId),
      ),
      data: (all) {
        final abandoned = all
            .where((e) => e.status == BookStatus.abandoned)
            .toList();
        if (widget.compact) {
          return _Shelves(
            entries: all
                .where((e) => e.status != BookStatus.abandoned)
                .toList(),
            editable: false,
            minRows: 1,
          );
        }
        final shelf = all
            .where((e) => BookStatus.shelf.contains(e.status))
            .toList();
        final sorting = own && _sorting;
        final shown = sorting
            ? (_ordered ?? shelf)
            : _filter == null
            ? shelf
            : shelf.where((e) => e.status == _filter).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sorting works on the full shelf, so the filters step aside.
            if (!sorting)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Alle',
                      count: shelf.length,
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final status in BookStatus.shelf)
                      _FilterChip(
                        label: status.label,
                        count: shelf.where((e) => e.status == status).length,
                        selected: _filter == status,
                        onTap: () => setState(() => _filter = status),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (sorting)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Buch gedrückt halten und auf den Platz eines anderen ziehen.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            _Shelves(
              entries: shown,
              editable: own,
              minRows: 2,
              onMove: sorting ? (from, to) => _move(shelf, from, to) : null,
              showStatusBadge: _filter == null,
              emptyText: shelf.isEmpty
                  ? (own
                        ? 'Dein Regal ist noch leer. Füge Bücher hinzu, die du besitzt.'
                        : 'Noch keine Bücher im Regal.')
                  : 'Keine Bücher in „${_filter?.label}“.',
            ),
            if (abandoned.isNotEmpty)
              _AbandonedCorner(entries: abandoned, editable: own),
            if (own) ...[
              const SizedBox(height: 12),
              sorting
                  ? Center(
                      child: FilledButton(
                        onPressed: () => setState(() => _sorting = false),
                        child: const Text('Fertig'),
                      ),
                    )
                  : Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => context.push('/books/search'),
                          icon: const Icon(Icons.add),
                          label: const Text('Buch hinzufügen'),
                        ),
                        if (shelf.length > 1)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _sorting = true;
                              _filter = null;
                            }),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Sortieren'),
                          ),
                      ],
                    ),
            ],
          ],
        );
      },
    );
  }
}

/// Abandoned books: collapsed below the shelf so they don't clutter it.
class _AbandonedCorner extends StatefulWidget {
  const _AbandonedCorner({required this.entries, required this.editable});

  final List<UserBook> entries;
  final bool editable;

  @override
  State<_AbandonedCorner> createState() => _AbandonedCornerState();
}

class _AbandonedCornerState extends State<_AbandonedCorner> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline, color: muted),
          title: Text('Abgebrochen  ${widget.entries.length}'),
          trailing: AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more),
          ),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Opacity(
            opacity: 0.7,
            child: _Shelves(
              entries: widget.entries,
              editable: widget.editable,
              minRows: 1,
            ),
          ),
      ],
    );
  }
}

/// Books the user wants, kept apart from the shelf of owned books.
class WishlistView extends ConsumerWidget {
  const WishlistView({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = userId == null;
    return _entries(ref, userId).when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ErrorState(
        message: 'Wunschliste konnte nicht geladen werden.',
        onRetry: () => _retry(ref, userId),
      ),
      data: (all) {
        final wishes = all
            .where((e) => e.status == BookStatus.wantToRead)
            .toList();
        if (wishes.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border,
            title: 'Wunschliste ist leer',
            message: own
                ? 'Merke dir Bücher, die du haben oder lesen möchtest.'
                : null,
            action: own
                ? OutlinedButton.icon(
                    onPressed: () => context.push('/books/search'),
                    icon: const Icon(Icons.add),
                    label: const Text('Buch suchen'),
                  )
                : null,
          );
        }
        return LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            final cols = c.maxWidth >= 600 ? 6 : 3;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 16,
              children: [
                for (final e in wishes)
                  SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BookCover(entry: e, width: w, editable: own),
                        const SizedBox(height: 6),
                        Text(
                          e.book?.title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.2),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      visualDensity: VisualDensity.compact,
      label: Text.rich(
        TextSpan(
          text: label,
          children: [
            TextSpan(
              text: '  $count',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );
}

/// Rows of covers standing on boards. Always draws [minRows] boards so a
/// small collection still reads as a shelf that fills up.
class _Shelves extends StatelessWidget {
  const _Shelves({
    required this.entries,
    required this.editable,
    this.minRows = 1,
    this.showStatusBadge = false,
    this.emptyText,
    this.onMove,
  });

  final List<UserBook> entries;
  final bool editable;
  final int minRows;
  final bool showStatusBadge;
  final String? emptyText;

  /// Sort mode: drag a cover onto another to move it there.
  final void Function(String fromId, String toId)? onMove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      decoration: BoxDecoration(
        color: _shelfBack,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 10.0;
          final cols = c.maxWidth >= 560 ? 6 : 4;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          final rows = <List<UserBook>>[
            for (var i = 0; i < entries.length; i += cols)
              entries.sublist(i, (i + cols).clamp(0, entries.length)),
          ];
          while (rows.length < minRows) {
            rows.add(const []);
          }
          return Column(
            children: [
              for (var r = 0; r < rows.length; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      SizedBox(
                        height: w * 1.5,
                        child: entries.isEmpty && r == 0 && emptyText != null
                            ? Center(
                                child: Text(
                                  emptyText!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (var i = 0; i < rows[r].length; i++) ...[
                                    if (i > 0) const SizedBox(width: gap),
                                    _Arrive(
                                      // Re-run when the shown books change (filter switch).
                                      key: ValueKey(rows[r][i].id),
                                      order: r * cols + i,
                                      child: onMove == null
                                          ? _BookCover(
                                              entry: rows[r][i],
                                              width: w,
                                              editable: editable,
                                              showStatusBadge: showStatusBadge,
                                            )
                                          : _Sortable(
                                              entry: rows[r][i],
                                              width: w,
                                              onMove: onMove!,
                                              child: _BookCover(
                                                entry: rows[r][i],
                                                width: w,
                                                editable: false,
                                              ),
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      const _Board(),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// In sort mode: hold a cover, drag it onto another, it takes that place.
class _Sortable extends StatelessWidget {
  const _Sortable({
    required this.entry,
    required this.width,
    required this.onMove,
    required this.child,
  });

  final UserBook entry;
  final double width;
  final void Function(String fromId, String toId) onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    onWillAcceptWithDetails: (d) => d.data != entry.id,
    onAcceptWithDetails: (d) => onMove(d.data, entry.id),
    builder: (context, candidates, _) => LongPressDraggable<String>(
      data: entry.id,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.08,
          child: SizedBox(width: width, height: width * 1.5, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // Foreground: the highlight must not widen the cover.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            width: 2,
            color: candidates.isEmpty ? Colors.transparent : AppColors.burgundy,
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// Books slide up onto the board one after another; skipped with reduced motion.
class _Arrive extends StatelessWidget {
  const _Arrive({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    const base = 380;
    final delay = 45 * order.clamp(0, 12);
    final total = base + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 28),
          child: child,
        ),
      ),
    );
  }
}

/// Covers dip slightly while pressed, like taking a book off the shelf.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool v) {
    // The cover can be swapped out mid-press (drag in sort mode).
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _down ? const Offset(0, -0.03) : Offset.zero,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    ),
  );
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) => Container(
    height: 10,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_boardTop, _boardEdge],
      ),
      borderRadius: BorderRadius.circular(3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 6,
          offset: Offset(0, 4),
        ),
      ],
    ),
  );
}

class _BookCover extends ConsumerWidget {
  const _BookCover({
    required this.entry,
    required this.width,
    required this.editable,
    this.showStatusBadge = false,
  });

  final UserBook entry;
  final double width;
  final bool editable;
  final bool showStatusBadge;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final choice = await showBookStatusSheet(
      context,
      current: entry.status,
      title: entry.book?.title,
    );
    if (choice == null) return;
    final repo = ref.read(bookRepositoryProvider);
    try {
      switch (choice) {
        case SetStatus(:final status):
          if (status == entry.status) return;
          await repo.updateStatus(entry.id, status);
        case RemoveBook():
          await repo.removeFromShelf(entry.id);
      }
      ref.invalidate(bookshelfProvider);
      ref.invalidate(myShelfEntryProvider(entry.bookId));
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
    final book = entry.book;
    final workId = book?.openLibraryId;
    final height = width * 1.5;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final title = book?.title ?? 'Buch';
    final progress = entry.status == BookStatus.reading ? entry.progress : null;

    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: book?.coverUrl == null
          ? _SpineFallback(title: title, width: width, height: height)
          : CachedNetworkImage(
              imageUrl: book!.coverUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              memCacheWidth: (width * dpr).round(),
              placeholder: (_, _) =>
                  Container(width: width, height: height, color: _boardTop),
              errorWidget: (_, _, _) =>
                  _SpineFallback(title: title, width: width, height: height),
            ),
    );

    return Semantics(
      button: true,
      label:
          '$title${book?.author == null ? '' : ' von ${book!.author}'}, ${entry.status.label}'
          '${progress == null ? '' : ', ${(progress * 100).round()} Prozent gelesen'}',
      hint: editable ? 'Lange drücken zum Ändern' : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: workId == null
            ? null
            : () => context.push('/books/${normalizeWorkId(workId)}'),
        onLongPress: editable ? () => _edit(context, ref) : null,
        child: _PressScale(
          child: Container(
            width: width,
            height: height,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(1, 2),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover,
                if (showStatusBadge && entry.status == BookStatus.reading)
                  const Positioned(
                    top: 0,
                    right: 6,
                    child: Icon(
                      Icons.bookmark,
                      color: AppColors.burgundy,
                      size: 20,
                    ),
                  ),
                if (progress != null)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: AppColors.burgundy,
                        backgroundColor: const Color(0xCCFFFFFF),
                      ),
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

/// Stand-in when there is no cover: a coloured board with the title.
class _SpineFallback extends StatelessWidget {
  const _SpineFallback({
    required this.title,
    required this.width,
    required this.height,
  });

  final String title;
  final double width;
  final double height;

  static const _colors = [
    AppColors.burgundy,
    Color(0xFF3E5C50),
    Color(0xFF34495E),
    Color(0xFF85661A),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    color: _colors[title.hashCode.abs() % _colors.length],
    padding: const EdgeInsets.all(6),
    alignment: Alignment.center,
    child: Text(
      title,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
    ),
  );
}
