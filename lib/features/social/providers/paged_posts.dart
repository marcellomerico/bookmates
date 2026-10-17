import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../auth/providers/auth_provider.dart';
import 'social_providers.dart';

enum _Kind { feed, group, author, book }

/// Which post list to page through; usable as a family key.
class PostSource {
  const PostSource._(this._kind, [this.id]);

  /// Posts by followed users + own; global public posts when following nobody.
  static const feed = PostSource._(_Kind.feed);
  const PostSource.group(String groupId) : this._(_Kind.group, groupId);
  const PostSource.author(String authorId) : this._(_Kind.author, authorId);
  const PostSource.book(String bookId) : this._(_Kind.book, bookId);

  final _Kind _kind;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is PostSource && other._kind == _kind && other.id == id;

  @override
  int get hashCode => Object.hash(_kind, id);

  @override
  String toString() => 'PostSource.${_kind.name}(${id ?? ''})';
}

class PagedPosts {
  const PagedPosts({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<Post> items;
  final bool hasMore;
  final bool loadingMore;
}

class PagedPostsNotifier
    extends AutoDisposeFamilyAsyncNotifier<PagedPosts, PostSource> {
  static const pageSize = 20;

  /// Feed authors resolved on first page; null = global feed.
  List<String>? _feedAuthors;

  @override
  Future<PagedPosts> build(PostSource arg) {
    ref.watch(currentUserProvider);
    ref.watch(postRepositoryProvider);
    return _firstPage();
  }

  Future<PagedPosts> _firstPage() async {
    if (arg._kind == _Kind.feed) {
      final user = ref.read(currentUserProvider);
      if (user == null) return const PagedPosts(items: [], hasMore: false);
      final following =
          await ref.read(followRepositoryProvider).getFollowingIds(user.id);
      _feedAuthors =
          following.isEmpty ? null : {...following, user.id}.toList();
    }
    final page = await _fetch(null);
    return PagedPosts(items: page, hasMore: page.length == pageSize);
  }

  Future<List<Post>> _fetch(DateTime? before) async {
    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(postRepositoryProvider);
    if (arg._kind == _Kind.author) {
      return repo.getPostsByAuthor(
        arg.id!,
        currentUserId: userId,
        before: before,
        limit: pageSize,
      );
    }
    if (userId == null) return const [];
    return repo.getFeed(
      currentUserId: userId,
      authorIds: arg._kind == _Kind.feed ? _feedAuthors : null,
      groupId: arg._kind == _Kind.group ? arg.id : null,
      bookId: arg._kind == _Kind.book ? arg.id : null,
      before: before,
      limit: pageSize,
    );
  }

  /// Appends the next page. Rethrows on failure (state keeps the loaded items).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        state.isLoading ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    final loading = PagedPosts(
      items: current.items,
      hasMore: true,
      loadingMore: true,
    );
    state = AsyncData(loading);
    final link = ref.keepAlive(); // don't dispose mid-request
    try {
      final page = await _fetch(current.items.last.createdAt);
      if (!identical(state.valueOrNull, loading)) return; // refreshed meanwhile
      final seen = {for (final p in current.items) p.id};
      state = AsyncData(PagedPosts(
        items: [...current.items, ...page.where((p) => seen.add(p.id))],
        hasMore: page.length == pageSize,
      ));
    } catch (_) {
      if (identical(state.valueOrNull, loading)) state = AsyncData(current);
      rethrow;
    } finally {
      link.close();
    }
  }

  /// Reloads the first page, keeping the current items visible meanwhile.
  Future<void> refresh() async {
    state = const AsyncLoading<PagedPosts>().copyWithPrevious(state);
    state = await AsyncValue.guard(_firstPage);
  }
}

final pagedPostsProvider = AsyncNotifierProvider.autoDispose
    .family<PagedPostsNotifier, PagedPosts, PostSource>(PagedPostsNotifier.new);
