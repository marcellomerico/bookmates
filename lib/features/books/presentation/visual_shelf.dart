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
import '../../../models/shelf_decor.dart';
import '../../social/providers/social_providers.dart';

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
  bool _decorating = false;
  DecorItem _item = DecorItem.plant;
  List<DecorPiece>? _pending; // optimistic copy while saving

  List<DecorPiece> _decor() {
    if (_pending != null) return _pending!;
    final profile = widget.userId == null
        ? ref.watch(currentProfileProvider).valueOrNull
        : ref.watch(profileByIdProvider(widget.userId!)).valueOrNull;
    return profile?.shelfDecor ?? const [];
  }

  Future<void> _save(List<DecorPiece> next) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending = next);
    try {
      await ref.read(profileRepositoryProvider).updateShelfDecor(user.id, next);
      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Deko konnte nicht gespeichert werden.')),
      );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _place(List<DecorPiece> current, int row, int slot) {
    if (current.length >= DecorPiece.maxPieces) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximal 16 Deko-Teile pro Regal.')),
      );
      return;
    }
    if (row > DecorPiece.maxRow || slot > DecorPiece.maxSlot) return;
    _save([...current, DecorPiece(_item, row, slot)]);
  }

  Widget _palette() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in DecorItem.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  selected: item == _item,
                  label: Text('${item.emoji} ${item.label}'),
                  onSelected: (_) => setState(() => _item = item),
                ),
              ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Deko wählen und auf einen freien Platz tippen. Antippen entfernt sie wieder.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
    ],
  );

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
        final shown = _filter == null
            ? shelf
            : shelf.where((e) => e.status == _filter).toList();
        final decor = _decor();
        final decorating = own && _decorating;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            if (decorating) _palette(),
            _Shelves(
              entries: shown,
              editable: own,
              minRows: 2,
              showStatusBadge: _filter == null,
              // Positions only make sense on the full shelf.
              decor: _filter == null ? decor : const [],
              decorating: decorating,
              onEmptyTap: (row, slot) => _place(decor, row, slot),
              onDecorTap: (piece) => _save([...decor]..remove(piece)),
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
              decorating
                  ? Center(
                      child: FilledButton(
                        onPressed: () => setState(() => _decorating = false),
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
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _decorating = true;
                            _filter = null;
                          }),
                          icon: const Icon(Icons.local_florist_outlined),
                          label: const Text('Dekorieren'),
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
    this.decor = const [],
    this.decorating = false,
    this.onEmptyTap,
    this.onDecorTap,
  });

  final List<UserBook> entries;
  final bool editable;
  final int minRows;
  final bool showStatusBadge;
  final String? emptyText;
  final List<DecorPiece> decor;

  /// Edit mode: empty slots become targets, pieces can be removed.
  final bool decorating;
  final void Function(int row, int slot)? onEmptyTap;
  final void Function(DecorPiece piece)? onDecorTap;

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
          final rows = layoutShelf(
            entries,
            decor,
            cols: cols,
            minRows: minRows,
            extraRows: decorating ? 1 : 0,
          );
          final showEmptyText =
              entries.isEmpty &&
              decor.isEmpty &&
              !decorating &&
              emptyText != null;
          return Column(
            children: [
              for (var r = 0; r < rows.length; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      SizedBox(
                        height: w * 1.5,
                        child: showEmptyText && r == 0
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
                                  for (final slot in rows[r]) ...[
                                    if (slot.slot > 0)
                                      const SizedBox(width: gap),
                                    switch (slot) {
                                      BookSlot(:final book) => _Arrive(
                                        // Re-run when the shown books change (filter switch).
                                        key: ValueKey(book.id),
                                        order: slot.row * cols + slot.slot,
                                        child: _BookCover(
                                          entry: book,
                                          width: w,
                                          editable: editable && !decorating,
                                          showStatusBadge: showStatusBadge,
                                        ),
                                      ),
                                      DecorSlot(:final piece) => _Decor(
                                        piece: piece,
                                        width: w,
                                        removable: decorating,
                                        onTap: onDecorTap,
                                      ),
                                      EmptySlot() =>
                                        decorating
                                            ? _DropTarget(
                                                width: w,
                                                onTap: () => onEmptyTap?.call(
                                                  slot.row,
                                                  slot.slot,
                                                ),
                                              )
                                            : SizedBox(width: w),
                                    },
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

/// A decoration standing on the board.
class _Decor extends StatelessWidget {
  const _Decor({
    required this.piece,
    required this.width,
    required this.removable,
    this.onTap,
  });

  final DecorPiece piece;
  final double width;
  final bool removable;
  final void Function(DecorPiece piece)? onTap;

  @override
  Widget build(BuildContext context) {
    final emoji = Text(
      piece.item.emoji,
      style: TextStyle(fontSize: width * 0.62, height: 1),
    );
    return Semantics(
      label: piece.item.label,
      button: removable,
      hint: removable ? 'Antippen zum Entfernen' : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: removable ? () => onTap?.call(piece) : null,
        child: SizedBox(
          width: width,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Padding(padding: const EdgeInsets.only(bottom: 2), child: emoji),
              if (removable)
                const Positioned(
                  top: -4,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.burgundy,
                    child: Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free place while decorating.
class _DropTarget extends StatelessWidget {
  const _DropTarget({required this.width, required this.onTap});

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Freier Platz',
    hint: 'Antippen, um die gewählte Deko hierhin zu stellen',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: width * 1.2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.muted.withValues(alpha: 0.5)),
        ),
        child: const Icon(Icons.add, color: AppColors.muted),
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
    if (_down != v) setState(() => _down = v);
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
