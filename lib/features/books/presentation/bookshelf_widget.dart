import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/user_book.dart';
import '../../../repositories/open_library_repository.dart';
import '../providers/books_provider.dart';

class BookshelfWidget extends ConsumerStatefulWidget {
  const BookshelfWidget({super.key, this.compact = false, this.userId});

  final bool compact;
  final String? userId;

  @override
  ConsumerState<BookshelfWidget> createState() => _BookshelfWidgetState();
}

class _BookshelfWidgetState extends ConsumerState<BookshelfWidget> {
  BookStatus _selected = BookStatus.reading;

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final compact = widget.compact;
    final bookshelf = userId == null
        ? ref.watch(bookshelfProvider)
        : ref.watch(bookshelfByUserProvider(userId));
    final readOnly = userId != null;

    return bookshelf.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(
        message: 'Bücherregal konnte nicht geladen werden.',
        onRetry: () => userId == null
            ? ref.invalidate(bookshelfProvider)
            : ref.invalidate(bookshelfByUserProvider(userId)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return SoftCard(
            child: Column(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.burgundy,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Noch keine Bücher',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Füge dein erstes Buch hinzu.',
                  style: TextStyle(color: AppColors.muted),
                ),
                if (!compact && !readOnly) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/books/search'),
                    icon: const Icon(Icons.add),
                    label: const Text('Buch hinzufügen'),
                  ),
                ],
              ],
            ),
          );
        }

        final filtered = entries.where((e) => e.status == _selected).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Bücherregal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (!compact && !readOnly)
                  TinyPill(
                    label: 'Hinzufügen',
                    filled: true,
                    onTap: () => context.push('/books/search'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                for (final status in const [
                  BookStatus.reading,
                  BookStatus.read,
                  BookStatus.wantToRead,
                ])
                  ChoiceChip(
                    label: Text(status.label),
                    selected: _selected == status,
                    onSelected: (_) => setState(() => _selected = status),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                child: Center(
                  child: Text(
                    'Keine Bücher in „${_selected.label}"',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _BookshelfTile(
                  key: ValueKey(filtered[i].id),
                  entry: filtered[i],
                  readOnly: readOnly,
                ),
              ],
          ],
        );
      },
    );
  }
}

class _BookshelfTile extends ConsumerStatefulWidget {
  const _BookshelfTile({super.key, required this.entry, required this.readOnly});

  final UserBook entry;
  final bool readOnly;

  @override
  ConsumerState<_BookshelfTile> createState() => _BookshelfTileState();
}

class _BookshelfTileState extends ConsumerState<_BookshelfTile> {
  bool _updating = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _updating = true);
    try {
      await action();
      ref.invalidate(bookshelfProvider);
      ref.invalidate(bookshelfByUserProvider(widget.entry.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateStatus(BookStatus status) => _run(
    () => ref.read(bookRepositoryProvider).updateStatus(widget.entry.id, status),
  );

  Future<void> _updateRating(int? rating) => _run(
    () => ref.read(bookRepositoryProvider).updateRating(widget.entry.id, rating),
  );

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Buch entfernen?'),
        content: const Text('Das Buch wird aus deinem Bücherregal entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => ref.read(bookRepositoryProvider).removeFromShelf(widget.entry.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.entry.book;
    if (book == null) return const SizedBox.shrink();

    final workId = book.openLibraryId;
    return ListTile(
      onTap: workId == null
          ? null
          : () => context.push('/books/${normalizeWorkId(workId)}'),
      leading: _Cover(url: book.coverUrl),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (book.author != null) Text(book.author!),
          if (widget.entry.status == BookStatus.read) ...[
            const SizedBox(height: 4),
            Semantics(
              label: '${widget.entry.rating ?? 0} von 5 Sternen',
              child: Wrap(
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  tooltip: widget.readOnly
                      ? null
                      : 'Bewertung: $star ${star == 1 ? 'Stern' : 'Sterne'} setzen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _updating || widget.readOnly
                      ? null
                      : () => _updateRating(star),
                  icon: Icon(
                    star <= (widget.entry.rating ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    color: AppColors.gold,
                    size: 20,
                  ),
                );
              }),
            )),
          ],
        ],
      ),
      trailing: widget.readOnly
          ? null
          : _updating
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              tooltip: 'Optionen',
              onSelected: (value) {
                if (value == 'remove') {
                  _remove();
                } else {
                  _updateStatus(BookStatus.fromDb(value));
                }
              },
              itemBuilder: (context) => [
                ...BookStatus.values.map(
                  (status) => PopupMenuItem(
                    value: status.dbValue,
                    child: Text(status.label),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'remove', child: Text('Entfernen')),
              ],
            ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 40,
        height: 56,
        color: AppColors.parchment,
        child: const Icon(Icons.menu_book, color: AppColors.muted),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 40,
        height: 56,
        fit: BoxFit.cover,
        memCacheWidth: (40 * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 300),
        errorWidget: (_, _, _) => Container(
          width: 40,
          height: 56,
          color: AppColors.parchment,
          child: const Icon(Icons.menu_book, color: AppColors.muted),
        ),
      ),
    );
  }
}
