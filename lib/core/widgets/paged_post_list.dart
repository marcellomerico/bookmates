import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/social/providers/paged_posts.dart';
import 'post_card.dart';
import 'state_views.dart';

/// List children for a paged post list, to spread into a lazy ListView.
/// The trailing row loads the next page once the ListView builds it (near the end).
List<Widget> pagedPostListItems(
  WidgetRef ref,
  PostSource source, {
  required String errorMessage,
  required Widget empty,
  Widget loading = const Center(child: CircularProgressIndicator()),
}) {
  return ref
      .watch(pagedPostsProvider(source))
      .when(
        loading: () => [loading],
        error: (_, _) => [
          ErrorState(
            message: errorMessage,
            onRetry: () => ref.invalidate(pagedPostsProvider(source)),
          ),
        ],
        data: (page) => page.items.isEmpty
            ? [empty]
            : [
                for (final post in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(post: post),
                  ),
                if (page.hasMore) _LoadMoreRow(source: source),
              ],
      );
}

class _LoadMoreRow extends ConsumerStatefulWidget {
  const _LoadMoreRow({required this.source});

  final PostSource source;

  @override
  ConsumerState<_LoadMoreRow> createState() => _LoadMoreRowState();
}

class _LoadMoreRowState extends ConsumerState<_LoadMoreRow> {
  @override
  void initState() {
    super.initState();
    // Only on first build: after a failed load the element survives, so no retry loop.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      await ref.read(pagedPostsProvider(widget.source).notifier).loadMore();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadingMore = ref.watch(
      pagedPostsProvider(
        widget.source,
      ).select((s) => s.valueOrNull?.loadingMore ?? false),
    );
    return SizedBox(
      height: 56,
      child: Center(
        child: loadingMore
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: _load, child: const Text('Mehr laden')),
      ),
    );
  }
}
