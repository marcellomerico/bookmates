import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../../repositories/post_repository.dart';
import '../../auth/providers/auth_provider.dart';
import 'like_overrides.dart';
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
  }) : _feedAuthors = null;

  const PagedPosts._({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    this._feedAuthors,
  });

  final List<Post> items;
  final bool hasMore;
  final bool loadingMore;

  /// Feed authors resolved with the first page; null = global feed.
  /// Kept on the state so a stale refresh can't leak them into later pages.
  final List<String>? _feedAuthors;
}

class PagedPostsNotifier
    extends AutoDisposeFamilyAsyncNotifier<PagedPosts, PostSource> {
  static const pageSize = 20;

  /// Bumped by every refresh; older in-flight requests compare and bail.
  int _token = 0;

  @override
  Future<PagedPosts> build(PostSource arg) {
    ref.watch(currentUserProvider);
    ref.watch(postRepositoryProvider);
    return _firstPage();
  }

  Future<PagedPosts> _firstPage() async {
    List<String>? authors;
    if (arg._kind == _Kind.feed) {
      final user = ref.read(currentUserProvider);
      if (user == null) return const PagedPosts(items: [], hasMore: false);
      final following =
          await ref.read(followRepositoryProvider).getFollowingIds(user.id);
      authors = following.isEmpty ? null : {...following, user.id}.toList();
    }
    final page = await _fetch(null, authors);
    _reconcileLikes(page);
    return PagedPosts._(
      items: page,
      hasMore: page.length == pageSize,
      feedAuthors: authors,
    );
  }

  // Drops optimistic like overrides that this fresh server data confirms.
  void _reconcileLikes(List<Post> page) =>
      ref.read(likeOverridesProvider.notifier).reconcile(page);

  Future<List<Post>> _fetch(PostCursor? after, List<String>? authors) async {
    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(postRepositoryProvider);
    if (arg._kind == _Kind.author) {
      return repo.getPostsByAuthor(
        arg.id!,
        currentUserId: userId,
        after: after,
        limit: pageSize,
      );
    }
    if (userId == null) return const [];
    return repo.getFeed(
      currentUserId: userId,
      authorIds: arg._kind == _Kind.feed ? authors : null,
      groupId: arg._kind == _Kind.group ? arg.id : null,
      bookId: arg._kind == _Kind.book ? arg.id : null,
      after: after,
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
    final token = _token;
    final loading = PagedPosts._(
      items: current.items,
      hasMore: true,
      loadingMore: true,
      feedAuthors: current._feedAuthors,
    );
    state = AsyncData(loading);
    bool stale() => token != _token || !identical(state.valueOrNull, loading);
    final link = ref.keepAlive(); // don't dispose mid-request
    try {
      final last = current.items.last;
      final page = await _fetch(
        (createdAt: last.createdAt, id: last.id),
        current._feedAuthors,
      );
      if (stale()) return; // refreshed meanwhile
      _reconcileLikes(page);
      final seen = {for (final p in current.items) p.id};
      state = AsyncData(PagedPosts._(
        items: [...current.items, ...page.where((p) => seen.add(p.id))],
        hasMore: page.length == pageSize,
        feedAuthors: current._feedAuthors,
      ));
    } catch (_) {
      if (!stale()) state = AsyncData(current);
      rethrow;
    } finally {
      link.close();
    }
  }

  /// Reloads the first page, keeping the current items visible meanwhile.
  /// Only the newest refresh may write its result.
  Future<void> refresh() async {
    final token = ++_token;
    state = const AsyncLoading<PagedPosts>().copyWithPrevious(state);
    final link = ref.keepAlive();
    try {
      final next = await AsyncValue.guard(_firstPage);
      if (token == _token) state = next;
    } finally {
      link.close();
    }
  }
}

final pagedPostsProvider = AsyncNotifierProvider.autoDispose
    .family<PagedPostsNotifier, PagedPosts, PostSource>(PagedPostsNotifier.new);
