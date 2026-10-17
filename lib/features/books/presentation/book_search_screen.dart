import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bookmates_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/user_book.dart';
import '../../../repositories/open_library_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/books_provider.dart';

class BookSearchScreen extends ConsumerStatefulWidget {
  const BookSearchScreen({
    super.key,
    this.initialStatus = BookStatus.wantToRead,
    this.fromOnboarding = false,
  });

  final BookStatus initialStatus;
  final bool fromOnboarding;

  @override
  ConsumerState<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends ConsumerState<BookSearchScreen> {
  final _searchController = TextEditingController();
  List<OpenLibraryBook> _results = [];
  bool _searching = false;
  String? _error;
  bool _searched = false;
  String? _addingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await ref
          .read(openLibraryRepositoryProvider)
          .search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Suche fehlgeschlagen. Bitte erneut versuchen.';
        _results = [];
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addBook(OpenLibraryBook book) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _addingId = book.openLibraryId);

    try {
      await ref
          .read(bookRepositoryProvider)
          .addToShelf(
            userId: user.id,
            result: book,
            status: widget.initialStatus,
          );
      ref.invalidate(bookshelfProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('„${book.title}" hinzugefügt')));
        if (widget.fromOnboarding) {
          context.pop(true);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buch konnte nicht hinzugefügt werden.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buch suchen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'z. B. Harry Potter',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton.filled(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? (_error != null
                    ? ErrorState(message: _error!, onRetry: _search)
                    : _searching
                        ? const Center(child: CircularProgressIndicator())
                        : _searched
                            ? const EmptyState(
                                icon: Icons.search_off,
                                title: 'Keine Treffer',
                                message: 'Versuche es mit einem anderen Titel oder Autor.',
                              )
                            : const EmptyState(
                                icon: Icons.menu_book_outlined,
                                title: 'Suche nach einem Buch',
                              ))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final book = _results[index];
                      final isAdding = _addingId == book.openLibraryId;

                      return SoftCard(
                        child: Semantics(
                          button: true,
                          label: 'Buchdetails öffnen: ${book.title}',
                          child: InkWell(
                            onTap: () => context.push(
                              '/books/${normalizeWorkId(book.openLibraryId)}',
                            ),
                            child: Row(
                          children: [
                            _BookCover(url: book.coverUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  if (book.author != null)
                                    Text(
                                      book.author!,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            isAdding
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Semantics(
                                    button: true,
                                    label: 'Zum Regal hinzufügen',
                                    excludeSemantics: true,
                                    child: InkWell(
                                      onTap: () => _addBook(book),
                                      borderRadius: BorderRadius.circular(24),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Center(
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: const BoxDecoration(
                                              color: AppColors.burgundy,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 40,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.parchment,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.menu_book, color: AppColors.muted, size: 20),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 42,
        height: 60,
        fit: BoxFit.cover,
        memCacheWidth: (42 * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 300),
        placeholder: (_, _) =>
            Container(width: 42, height: 60, color: AppColors.parchment),
        errorWidget: (_, _, _) => Container(
          width: 42,
          height: 60,
          color: AppColors.parchment,
          child: const Icon(Icons.menu_book, color: AppColors.muted, size: 20),
        ),
      ),
    );
  }
}
