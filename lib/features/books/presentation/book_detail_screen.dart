import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paged_post_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/book.dart';
import '../../../models/user_book.dart';
import '../../../repositories/open_library_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../providers/books_provider.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({super.key, required this.workId});

  final String workId;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _expanded = false;
  bool _busy = false;

  static const _statusLabels = {
    BookStatus.wantToRead: 'Will ich lesen',
    BookStatus.reading: 'Lese ich',
    BookStatus.read: 'Gelesen',
  };

  // Takes the container so it still works after the screen was popped.
  void _invalidateShelf(ProviderContainer container, String? bookId) {
    container.invalidate(bookshelfProvider);
    container.invalidate(bookByWorkIdProvider(widget.workId));
    if (bookId != null) {
      container.invalidate(myShelfEntryProvider(bookId));
      container.invalidate(bookReaderCountProvider(bookId));
    }
  }

  Future<void> _change(
    OpenLibraryWork work,
    Book? book,
    UserBook? entry,
    BookStatus status,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null || _busy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      final repo = ref.read(bookRepositoryProvider);
      String? bookId = book?.id;
      if (entry != null) {
        await repo.updateStatus(entry.id, status);
      } else {
        // addToShelf upserts the book row when it does not exist yet.
        final added = await repo.addToShelf(
          userId: user.id,
          result: OpenLibraryBook(
            openLibraryId: book?.openLibraryId ?? widget.workId,
            title: book?.title ?? work.title,
            author: book?.author,
            coverId: work.coverId,
            isbn: book?.isbn,
          ),
          status: status,
        );
        bookId = added.bookId;
      }
      _invalidateShelf(container, bookId);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(UserBook entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Aus Regal entfernen?'),
        content: const Text('Das Buch wird aus deinem Bücherregal entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      await ref.read(bookRepositoryProvider).removeFromShelf(entry.id);
      _invalidateShelf(container, entry.bookId);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
  }

  Future<void> _refresh(Book? book) async {
    ref.invalidate(openLibraryWorkProvider(widget.workId));
    ref.invalidate(bookByWorkIdProvider(widget.workId));
    if (book != null) {
      ref.invalidate(bookReaderCountProvider(book.id));
      ref.invalidate(myShelfEntryProvider(book.id));
      await ref
          .read(pagedPostsProvider(PostSource.book(book.id)).notifier)
          .refresh();
    }
    await ref
        .read(openLibraryWorkProvider(widget.workId).future)
        .catchError((_) => const OpenLibraryWork(id: '', title: ''));
  }

  @override
  Widget build(BuildContext context) {
    final workAsync = ref.watch(openLibraryWorkProvider(widget.workId));
    final book = ref.watch(bookByWorkIdProvider(widget.workId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Buchdetails')),
      body: workAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Buchdetails konnten nicht geladen werden.',
          onRetry: () => ref.invalidate(openLibraryWorkProvider(widget.workId)),
        ),
        data: (work) => RefreshIndicator(
          onRefresh: () => _refresh(book),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              _Header(work: work, book: book),
              const SizedBox(height: AppSpacing.l),
              _shelfControl(work, book),
              if (work.description != null) ...[
                const SizedBox(height: AppSpacing.l),
                _description(work.description!),
              ],
              if (work.subjects.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.l),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: [
                    for (final s in work.subjects.take(8))
                      Chip(
                        label: Text(s),
                        labelStyle: const TextStyle(fontSize: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (book != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Beiträge zu diesem Buch',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.m),
                ...pagedPostListItems(
                  ref,
                  PostSource.book(book.id),
                  errorMessage: 'Beiträge konnten nicht geladen werden.',
                  empty: const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Noch keine Beiträge zu diesem Buch',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shelfControl(OpenLibraryWork work, Book? book) {
    final entry = book == null
        ? null
        : ref.watch(myShelfEntryProvider(book.id)).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<BookStatus>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final e in _statusLabels.entries)
              ButtonSegment(
                value: e.key,
                label: Text(e.value, maxLines: 1, softWrap: false),
              ),
          ],
          selected: {?entry?.status},
          onSelectionChanged: _busy
              ? null
              : (s) {
                  if (s.isNotEmpty) _change(work, book, entry, s.first);
                },
        ),
        if (entry != null)
          TextButton(
            onPressed: _busy ? null : () => _remove(entry),
            child: const Text('Aus Regal entfernen'),
          ),
      ],
    );
  }

  Widget _description(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded ? null : 6,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: const TextStyle(height: 1.5),
        ),
        // shortcut: always offered, even when the text fits in 6 lines.
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Weniger' : 'Mehr anzeigen'),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.work, required this.book});

  final OpenLibraryWork work;
  final Book? book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readers = book == null
        ? null
        : ref.watch(bookReaderCountProvider(book!.id)).valueOrNull;
    const w = 120.0, h = 180.0;
    final placeholder = Container(
      width: w,
      height: h,
      color: AppColors.parchment,
      child: const Icon(Icons.menu_book, color: AppColors.muted, size: 40),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.s),
          child: work.coverUrl == null
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: work.coverUrl!,
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                  memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => placeholder,
                ),
        ),
        const SizedBox(width: AppSpacing.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(work.title, style: theme.textTheme.headlineMedium),
              if (book?.author != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  book!.author!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
              if (book != null && readers != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  readers == 0
                      ? 'Noch niemand hat es im Regal'
                      : readers == 1
                      ? '1 Leser hat es im Regal'
                      : '$readers Leser haben es im Regal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
