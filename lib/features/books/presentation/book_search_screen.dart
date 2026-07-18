import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
      final results = await ref.read(openLibraryRepositoryProvider).search(query);
      setState(() => _results = results);
    } catch (_) {
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
      await ref.read(bookRepositoryProvider).addToShelf(
            userId: user.id,
            result: book,
            status: widget.initialStatus,
          );
      ref.invalidate(bookshelfProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('„${book.title}" hinzugefügt')),
        );
        if (widget.fromOnboarding) {
          context.pop(true);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buch konnte nicht hinzugefügt werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buch suchen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Titel, Autor oder ISBN',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searching ? 'Suche läuft…' : 'Suche nach einem Buch',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final book = _results[index];
                      final isAdding = _addingId == book.openLibraryId;

                      return Card(
                        child: ListTile(
                          leading: _BookCover(url: book.coverUrl),
                          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: book.author != null ? Text(book.author!) : null,
                          trailing: isAdding
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: AppColors.burgundy,
                                  onPressed: () => _addBook(book),
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
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.menu_book, color: AppColors.muted, size: 20),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 40,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 40,
          height: 56,
          color: AppColors.parchment,
        ),
        errorWidget: (_, _, _) => Container(
          width: 40,
          height: 56,
          color: AppColors.parchment,
          child: const Icon(Icons.menu_book, color: AppColors.muted, size: 20),
        ),
      ),
    );
  }
}
