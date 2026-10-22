import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_book.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/books_provider.dart';
import '../suggestions.dart';

/// "Dein Buch des Tages" above the feed. Shows nothing while loading or without a pick.
class DailySuggestionCard extends ConsumerStatefulWidget {
  const DailySuggestionCard({super.key});

  @override
  ConsumerState<DailySuggestionCard> createState() =>
      _DailySuggestionCardState();
}

class _DailySuggestionCardState extends ConsumerState<DailySuggestionCard> {
  bool _busy = false;

  Future<void> _act(BookSuggestion s, {required bool wish}) async {
    final user = ref.read(currentUserProvider);
    if (user == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(bookRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (wish) {
        await repo.addToShelf(
          userId: user.id,
          result: s.book,
          status: BookStatus.wantToRead,
        );
        ref.invalidate(bookshelfProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text('„${s.book.title}“ steht auf deiner Wunschliste.'),
          ),
        );
      } else {
        await repo.dismissSuggestion(s.workId);
        ref.invalidate(dailySuggestionProvider);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = ref.watch(dailySuggestionProvider).valueOrNull;
    if (suggestion == null) return const SizedBox.shrink();
    final book = suggestion.book;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/books/${suggestion.workId}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: book.coverUrl == null
                      ? Container(
                          width: 72,
                          height: 108,
                          color: AppColors.parchment,
                          child: const Icon(Icons.menu_book_outlined),
                        )
                      : CachedNetworkImage(
                          placeholder: (_, _) => Container(
                            width: 72,
                            height: 108,
                            color: AppColors.parchment,
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 72,
                            height: 108,
                            color: AppColors.parchment,
                            child: const Icon(Icons.menu_book_outlined),
                          ),
                          imageUrl: book.coverUrl!,
                          width: 72,
                          height: 108,
                          fit: BoxFit.cover,
                          memCacheWidth:
                              (72 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'DEIN BUCH DES TAGES',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.burgundy,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              tooltip: 'Kein Interesse',
                              onPressed: _busy
                                  ? null
                                  : () => _act(suggestion, wish: false),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (book.author != null)
                        Text(
                          book.author!,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      const SizedBox(height: 6),
                      Text(suggestion.reason, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _act(suggestion, wish: true),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Auf die Wunschliste'),
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
