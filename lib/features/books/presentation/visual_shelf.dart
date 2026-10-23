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
import 'book_spine.dart';
import 'book_status_sheet.dart';

/// Shelf wood: a warm light board with a darker front edge.
Color _boardTop(BuildContext context) =>
    Color.lerp(context.palette.shelfWood, Colors.white, 0.3)!;

/// How books stand on the shelf: covers facing out or spines like a real shelf.
enum ShelfLook { covers, spines }

/// Kept for the session; shared by the own and other readers' shelves.
final shelfLookProvider = StateProvider<ShelfLook>((ref) => ShelfLook.spines);

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
        final look = ref.watch(shelfLookProvider);
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
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
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
                              count: shelf
                                  .where((e) => e.status == status)
                                  .length,
                              selected: _filter == status,
                              onTap: () => setState(() => _filter = status),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _LookToggle(
                    look: look,
                    onChanged: (l) =>
                        ref.read(shelfLookProvider.notifier).state = l,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (own && !sorting && _filter == BookStatus.read)
              const _YearGoalStrip(),
            if (!sorting && _filter == BookStatus.unread && shown.isNotEmpty)
              _ToReadStack(entries: shown),
            if (sorting)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Buch gedrückt halten und auf den Platz eines anderen ziehen.',
                  style: TextStyle(color: context.palette.muted, fontSize: 13),
                ),
              ),
            _Shelves(
              entries: shown,
              editable: own,
              minRows: 2,
              onMove: sorting ? (from, to) => _move(shelf, from, to) : null,
              spines: look == ShelfLook.spines,
              grouped: _filter == null,
              label: _filter?.label,
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

/// Covers or spines, as two small icon buttons.
class _LookToggle extends StatelessWidget {
  const _LookToggle({required this.look, required this.onChanged});

  final ShelfLook look;
  final ValueChanged<ShelfLook> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(ShelfLook value, IconData icon, String label) {
      final selected = look == value;
      return IconButton(
        tooltip: label,
        isSelected: selected,
        visualDensity: VisualDensity.compact,
        onPressed: () => onChanged(value),
        icon: Icon(
          icon,
          size: 20,
          color: selected ? context.palette.burgundy : context.palette.muted,
          semanticLabel: label,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(ShelfLook.covers, Icons.grid_view_rounded, 'Cover-Ansicht'),
        button(ShelfLook.spines, Icons.view_week_rounded, 'Buchrücken-Ansicht'),
      ],
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
    this.spines = false,
    this.grouped = false,
    this.label,
  });

  final List<UserBook> entries;
  final bool editable;
  final int minRows;
  final bool showStatusBadge;
  final String? emptyText;

  /// Sort mode: drag a cover onto another to move it there.
  final void Function(String fromId, String toId)? onMove;

  /// Spines instead of covers (ignored while sorting).
  final bool spines;

  /// "Alle": one shelf section per status, each under a brass plate.
  final bool grouped;

  /// Plate under the first board when not grouped (the filter's name).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return _Bookcase(
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 10.0, wallPadding = 8.0;
          final inner = c.maxWidth - 2 * wallPadding;
          final cols = c.maxWidth >= 560 ? 6 : 4;
          final w = (inner - gap * (cols - 1)) / cols;
          final rowHeight = w * 1.5;
          final useSpines = spines && onMove == null;
          final groups = grouped && onMove == null && entries.isNotEmpty
              ? [
                  for (final status in BookStatus.shelf)
                    if (entries.any((e) => e.status == status))
                      (
                        status.label.toUpperCase(),
                        entries.where((e) => e.status == status).toList(),
                      ),
                ]
              : [(label?.toUpperCase(), entries)];

          var order = 0;
          final shelves = <Widget>[];
          void addRow(Widget row, String? plate) => shelves
            ..add(_BackWall(height: rowHeight, child: row))
            ..add(_Board(label: plate));

          for (final (plate, items) in groups) {
            var first = true;
            if (useSpines) {
              for (final row in spineRows(items, inner, rowHeight)) {
                addRow(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (entry, size) in row) ...[
                        if (entry != row.first.$1) const SizedBox(width: 2),
                        _Arrive(
                          key: ValueKey('spine-${entry.id}'),
                          order: order++,
                          child: _SpineTile(
                            entry: entry,
                            size: size,
                            editable: editable,
                          ),
                        ),
                      ],
                    ],
                  ),
                  first ? plate : null,
                );
                first = false;
              }
            } else {
              for (var i = 0; i < items.length; i += cols) {
                final chunk = items.sublist(
                  i,
                  (i + cols).clamp(0, items.length),
                );
                addRow(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var j = 0; j < chunk.length; j++) ...[
                        if (j > 0) const SizedBox(width: gap),
                        _Arrive(
                          // Re-run when the shown books change (filter switch).
                          key: ValueKey(chunk[j].id),
                          order: order++,
                          child: onMove == null
                              ? _BookCover(
                                  entry: chunk[j],
                                  width: w,
                                  editable: editable,
                                  showStatusBadge: showStatusBadge,
                                )
                              : _Sortable(
                                  entry: chunk[j],
                                  width: w,
                                  onMove: onMove!,
                                  child: _BookCover(
                                    entry: chunk[j],
                                    width: w,
                                    editable: false,
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                  first ? plate : null,
                );
                first = false;
              }
            }
          }
          while (shelves.length < minRows * 2) {
            addRow(
              entries.isEmpty && shelves.isEmpty && emptyText != null
                  ? Center(
                      child: Text(
                        emptyText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFE9DDC8)),
                      ),
                    )
                  : const SizedBox.shrink(),
              null,
            );
          }
          return Column(children: shelves);
        },
      ),
    );
  }
}

/// Walnut library case: crown, side panels and plinth. Same in light and dark,
/// like a real piece of furniture.
class _Bookcase extends StatelessWidget {
  const _Bookcase({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      boxShadow: [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 30,
          offset: Offset(0, 18),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 16,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A4630), Color(0xFF4A3122), Color(0xFF3A2619)],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A3122), Color(0xFF5A3B28), Color(0xFF4A3122)],
            ),
          ),
          child: child,
        ),
        Container(
          height: 14,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A2619), Color(0xFF24170F)],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Dark back panel of one compartment, lit from above like by a reading lamp.
class _BackWall extends StatelessWidget {
  const _BackWall({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: height + 14,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.35, 1],
        colors: [Color(0xFF140D09), Color(0xFF2A1C14), Color(0xFF221710)],
      ),
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.3),
          radius: 1.1,
          colors: [Color(0x52FFC46E), Color(0x00FFC46E)],
        ),
      ),
      child: DecoratedBox(
        // Side shade where the panels meet the back wall.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            stops: [0, 0.06, 0.94, 1],
            colors: [
              Color(0x73000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0x73000000),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(alignment: Alignment.bottomLeft, child: child),
        ),
      ),
    ),
  );
}

/// A spine that opens the book and, on your own shelf, changes its status.
class _SpineTile extends ConsumerWidget {
  const _SpineTile({
    required this.entry,
    required this.size,
    required this.editable,
  });

  final UserBook entry;
  final Size size;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = entry.book;
    final workId = book?.openLibraryId;
    // Same actions as the cover; reuse its status sheet handling.
    final cover = _BookCover(
      entry: entry,
      width: size.width,
      editable: editable,
    );
    return Semantics(
      button: true,
      label:
          '${book?.title ?? 'Buch'}${book?.author == null ? '' : ' von ${book!.author}'}, ${entry.status.label}',
      hint: editable ? 'Lange drücken zum Ändern' : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: workId == null
            ? null
            : () => context.push('/books/${normalizeWorkId(workId)}'),
        onLongPress: editable ? () => cover._edit(context, ref) : null,
        child: _PressScale(
          child: BookSpine(entry: entry, size: size),
        ),
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
            color: candidates.isEmpty
                ? Colors.transparent
                : context.palette.burgundy,
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
  const _Board({this.label});

  /// Engraved brass plate on the front edge, e.g. "GELESEN".
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
    height: 18,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.35, 1],
        colors: [Color(0xFF7A5238), Color(0xFF5E3E2A), Color(0xFF3E281A)],
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 8,
          offset: Offset(0, 6),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: label == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE6C77A), Color(0xFFB48A3A)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label!,
              style: const TextStyle(
                color: Color(0xFF2A1A10),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
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
              placeholder: (_, _) => Container(
                width: width,
                height: height,
                color: _boardTop(context),
              ),
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
                  Positioned(
                    top: 0,
                    right: 6,
                    child: Icon(
                      Icons.bookmark,
                      color: context.palette.burgundy,
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
                        color: context.palette.burgundy,
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

  // Book colours, the same in both themes.
  static const _colors = [
    Color(0xFF7B3140),
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

/// "2026 · 18 / 30" above the read books, filling like on the Home ring.
class _YearGoalStrip extends ConsumerWidget {
  const _YearGoalStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(readingStatsProvider).valueOrNull;
    if (stats == null) return const SizedBox.shrink();
    final p = context.palette;
    final goal = stats.goal;
    final done = stats.finishedThisYear;
    final fraction = goal == null ? 0.0 : (done / goal).clamp(0.0, 1.0);
    return Semantics(
      label: goal == null
          ? '$done Bücher in diesem Jahr gelesen'
          : 'Jahresziel: $done von $goal Büchern',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(
              '${DateTime.now().year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: MediaQuery.disableAnimationsOf(context) ? fraction : 0,
                  end: fraction,
                ),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: p.goldText,
                    backgroundColor: p.parchment,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              goal == null ? '$done gelesen' : '$done / $goal',
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// The to-read pile: books lying on top of each other, slightly askew.
class _ToReadStack extends StatelessWidget {
  const _ToReadStack({required this.entries});

  final List<UserBook> entries;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pile = entries.take(6).toList();
    final pages = entries.fold<int>(0, (sum, e) => sum + (e.pageCount ?? 0));
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label:
          '${entries.length} ungelesene Bücher${pages > 0 ? ', zusammen etwa $pages Seiten' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 150,
              child: Column(
                children: [
                  for (final (i, e) in pile.reversed.indexed)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: still ? 1 : 0, end: 1),
                      duration: Duration(milliseconds: 350 + i * 90),
                      curve: Curves.easeOutBack,
                      builder: (context, t, child) => Transform.translate(
                        offset: Offset(0, -30 * (1 - t)),
                        child: Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: child,
                        ),
                      ),
                      child: Transform.translate(
                        offset: Offset(
                          ((e.bookId.hashCode % 13) - 6).toDouble(),
                          0,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 118.0 + (e.bookId.hashCode % 26),
                          height:
                              16.0 + ((e.pageCount ?? 250) / 90).clamp(0, 10),
                          decoration: BoxDecoration(
                            color: spineColor(e.bookId),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entries.length == 1
                        ? '1 Buch wartet'
                        : '${entries.length} Bücher warten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (pages > 0)
                    Text(
                      'zusammen etwa $pages Seiten',
                      style: TextStyle(color: p.muted, fontSize: 13),
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
