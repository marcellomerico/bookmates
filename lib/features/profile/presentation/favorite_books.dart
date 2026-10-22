import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_book.dart';
import '../../../repositories/open_library_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';

/// Up to three favourite books under the bio. [userId] null = own profile (editable).
class FavoriteBooks extends ConsumerWidget {
  const FavoriteBooks({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = userId == null;
    final shelf =
        (own
                ? ref.watch(bookshelfProvider)
                : ref.watch(bookshelfByUserProvider(userId!)))
            .valueOrNull ??
        const <UserBook>[];
    final favorites = favoriteBooks(shelf);
    final readBooks = shelf.where((e) => e.status == BookStatus.read).toList();

    if (favorites.isEmpty) {
      if (!own || readBooks.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => _pick(context, ref, readBooks, favorites),
          icon: const Icon(Icons.star_outline_rounded, size: 20),
          label: const Text('Lieblingsbücher auswählen'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                own ? 'Meine Empfehlungen' : 'Empfiehlt',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (own)
                IconButton(
                  tooltip: 'Empfehlungen bearbeiten',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _pick(context, ref, readBooks, favorites),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final entry in favorites) ...[
                _FavoriteCover(entry: entry),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<UserBook> readBooks,
    List<UserBook> current,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FavoritePicker(
        readBooks: readBooks,
        initial: [for (final e in current) e.id],
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(bookRepositoryProvider).setFavorites(user.id, picked);
      ref.invalidate(bookshelfProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Empfehlungen konnten nicht gespeichert werden.'),
        ),
      );
    }
  }
}

class _FavoriteCover extends StatelessWidget {
  const _FavoriteCover({required this.entry});
  final UserBook entry;

  @override
  Widget build(BuildContext context) {
    final book = entry.book;
    final title = book?.title ?? 'Buch';
    final workId = book?.openLibraryId;
    const width = 72.0, height = 108.0;
    final fallback = Container(
      width: width,
      height: height,
      color: AppColors.parchment,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(
        title,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
    return Semantics(
      button: true,
      label: 'Empfehlung: $title',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: workId == null
            ? null
            : () => context.push('/books/${normalizeWorkId(workId)}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: book?.coverUrl == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: book!.coverUrl!,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (width * MediaQuery.devicePixelRatioOf(context)).round(),
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// Checklist of read books, at most three; returns the chosen entry ids in order.
class FavoritePicker extends StatefulWidget {
  const FavoritePicker({
    super.key,
    required this.readBooks,
    required this.initial,
  });

  final List<UserBook> readBooks;
  final List<String> initial;

  @override
  State<FavoritePicker> createState() => _FavoritePickerState();
}

class _FavoritePickerState extends State<FavoritePicker> {
  late final List<String> _picked = [...widget.initial];

  void _toggle(String id) => setState(() {
    if (!_picked.remove(id) && _picked.length < 3) _picked.add(id);
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Bis zu 3 Lieblingsbücher',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Aus deinen gelesenen Büchern · ${_picked.length} von 3',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in widget.readBooks)
                  CheckboxListTile(
                    value: _picked.contains(entry.id),
                    activeColor: AppColors.burgundy,
                    title: Text(entry.book?.title ?? 'Buch'),
                    subtitle: entry.book?.author == null
                        ? null
                        : Text(entry.book!.author!),
                    onChanged: _picked.contains(entry.id) || _picked.length < 3
                        ? (_) => _toggle(entry.id)
                        : null,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, List.of(_picked)),
              child: const Text('Speichern'),
            ),
          ),
        ],
      ),
    );
  }
}
