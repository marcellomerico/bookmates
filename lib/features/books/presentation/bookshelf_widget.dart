import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bookmates_ui.dart';
import '../../../models/user_book.dart';
import '../providers/books_provider.dart';

class BookshelfWidget extends ConsumerWidget {
  const BookshelfWidget({super.key, this.compact = false, this.userId});

  final bool compact;
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelf = userId == null
        ? ref.watch(bookshelfProvider)
        : ref.watch(bookshelfByUserProvider(userId!));
    final readOnly = userId != null;

    return bookshelf.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Bücherregal konnte nicht geladen werden.'),
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

        return DefaultTabController(
          length: 3,
          child: Column(
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
                    GestureDetector(
                      onTap: () => context.push('/books/search'),
                      child: const TinyPill(label: 'Hinzufügen', filled: true),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Lese gerade'),
                  Tab(text: 'Gelesen'),
                  Tab(text: 'Möchte lesen'),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: compact ? 220 : 320,
                child: TabBarView(
                  children:
                      [
                        BookStatus.reading,
                        BookStatus.read,
                        BookStatus.wantToRead,
                      ].map((status) {
                        final filtered = entries
                            .where((e) => e.status == status)
                            .toList();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              'Keine Bücher in „${status.label}"',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _BookshelfTile(
                              entry: filtered[index],
                              readOnly: readOnly,
                            );
                          },
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BookshelfTile extends ConsumerStatefulWidget {
  const _BookshelfTile({required this.entry, required this.readOnly});

  final UserBook entry;
  final bool readOnly;

  @override
  ConsumerState<_BookshelfTile> createState() => _BookshelfTileState();
}

class _BookshelfTileState extends ConsumerState<_BookshelfTile> {
  bool _updating = false;

  Future<void> _updateStatus(BookStatus status) async {
    setState(() => _updating = true);
    try {
      await ref
          .read(bookRepositoryProvider)
          .updateStatus(widget.entry.id, status);
      ref.invalidate(bookshelfProvider);
      ref.invalidate(bookshelfByUserProvider(widget.entry.userId));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateRating(int? rating) async {
    setState(() => _updating = true);
    try {
      await ref
          .read(bookRepositoryProvider)
          .updateRating(widget.entry.id, rating);
      ref.invalidate(bookshelfProvider);
      ref.invalidate(bookshelfByUserProvider(widget.entry.userId));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _updating = true);
    try {
      await ref.read(bookRepositoryProvider).removeFromShelf(widget.entry.id);
      ref.invalidate(bookshelfProvider);
      ref.invalidate(bookshelfByUserProvider(widget.entry.userId));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.entry.book;
    if (book == null) return const SizedBox.shrink();

    return ListTile(
      leading: _Cover(url: book.coverUrl),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (book.author != null) Text(book.author!),
          if (widget.entry.status == BookStatus.read) ...[
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
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
            ),
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
