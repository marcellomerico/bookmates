import 'dart:async';

import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/social/providers/paged_posts.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/post.dart';
import 'package:booksquad/repositories/follow_repository.dart';
import 'package:booksquad/repositories/post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

Post _post(int i, {String prefix = 'p', DateTime? at}) => Post(
      id: '$prefix$i',
      authorId: 'a',
      content: 'post $i',
      postType: PostType.discussion,
      // Newest first: p0 is the most recent.
      createdAt: at ?? DateTime.utc(2026, 1, 1).subtract(Duration(minutes: i)),
    );

class FakePostRepository extends PostRepository {
  FakePostRepository(this.posts) : super(offlineClient());

  /// Must already be in (createdAt desc, id desc) order.
  List<Post> posts;
  int calls = 0;
  PostCursor? lastAfter;
  List<String>? lastAuthorIds;

  /// When set, the next request waits for it (captured per call).
  Completer<void>? gate;

  /// When true, requests throw after the gate.
  bool fail = false;

  /// Applied to the cursor time before filtering; simulates overlapping pages.
  Duration beforeShift = Duration.zero;

  Future<List<Post>> _page(PostCursor? after, int limit) async {
    calls++;
    lastAfter = after;
    final g = gate;
    if (g != null) await g.future;
    if (fail) throw Exception('network');
    if (after == null) return posts.take(limit).toList();
    final ts = after.createdAt.add(beforeShift);
    return posts
        .where((p) =>
            p.createdAt.isBefore(ts) ||
            (p.createdAt == ts && p.id.compareTo(after.id) < 0))
        .take(limit)
        .toList();
  }

  @override
  Future<List<Post>> getFeed({
    required String currentUserId,
    List<String>? authorIds,
    String? groupId,
    String? bookId,
    PostCursor? after,
    int limit = 20,
  }) {
    lastAuthorIds = authorIds;
    return _page(after, limit);
  }

  @override
  Future<List<Post>> getPostsByAuthor(
    String authorId, {
    String? currentUserId,
    PostCursor? after,
    int limit = 20,
  }) =>
      _page(after, limit);
}

class FakeFollowRepository extends FollowRepository {
  FakeFollowRepository(this.ids) : super(offlineClient());
  final List<String> ids;

  @override
  Future<List<String>> getFollowingIds(String userId) async => ids;
}

void main() {
  late FakePostRepository repo;
  late ProviderContainer container;
  const src = PostSource.group('g1');

  setUp(() {
    repo = FakePostRepository(List.generate(45, _post));
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(testUser('me')),
        postRepositoryProvider.overrideWithValue(repo),
      ],
    );
    container.listen(pagedPostsProvider(src), (_, _) {});
  });
  tearDown(() => container.dispose());

  PagedPostsNotifier notifier() => container.read(pagedPostsProvider(src).notifier);

  test('PostSource equality makes it usable as a family key', () {
    expect(const PostSource.group('x'), PostSource.group('x'.toString()));
    expect(PostSource.author('x').hashCode, PostSource.author('x').hashCode);
    expect(const PostSource.group('x') == const PostSource.author('x'), isFalse);
  });

  test('pages through 45 posts: 20, 40, 45, then no-op', () async {
    var page = await container.read(pagedPostsProvider(src).future);
    expect(page.items.length, 20);
    expect(page.hasMore, isTrue);

    await notifier().loadMore();
    page = container.read(pagedPostsProvider(src)).requireValue;
    expect(page.items.length, 40);
    expect(page.hasMore, isTrue);

    await notifier().loadMore();
    page = container.read(pagedPostsProvider(src)).requireValue;
    expect(page.items.length, 45);
    expect(page.hasMore, isFalse);
    expect(page.items.map((p) => p.id).toSet().length, 45);

    final callsBefore = repo.calls;
    await notifier().loadMore();
    expect(repo.calls, callsBefore);
    expect(container.read(pagedPostsProvider(src)).requireValue.items.length, 45);
  });

  test('dedupes overlapping pages by id', () async {
    await container.read(pagedPostsProvider(src).future);
    // Cursor p19 shifted to between p16 and p17: next page repeats p17–p19.
    repo.beforeShift = const Duration(minutes: 2, seconds: 30);
    await notifier().loadMore();
    final items = container.read(pagedPostsProvider(src)).requireValue.items;
    expect(items.length, 37);
    expect(items.map((p) => p.id).toSet().length, items.length);
  });

  test('loadMore while loading more is ignored', () async {
    await container.read(pagedPostsProvider(src).future);
    final a = notifier().loadMore();
    expect(container.read(pagedPostsProvider(src)).requireValue.loadingMore, isTrue);
    final b = notifier().loadMore();
    await Future.wait([a, b]);
    expect(container.read(pagedPostsProvider(src)).requireValue.items.length, 40);
  });

  test('refresh resets to the first page', () async {
    await container.read(pagedPostsProvider(src).future);
    await notifier().loadMore();
    await notifier().refresh();
    final page = container.read(pagedPostsProvider(src)).requireValue;
    expect(page.items.length, 20);
    expect(page.hasMore, isTrue);
  });

  test('cursor carries the last id so equal timestamps are not skipped', () async {
    final at = DateTime.utc(2026);
    // Same createdAt for all; two-digit ids p34..p10 sort like id desc.
    repo.posts = [for (var i = 34; i >= 10; i--) _post(i, at: at)];
    await container.read(pagedPostsProvider(src).future);
    await notifier().refresh(); // setUp already loaded the old list
    await notifier().loadMore();
    expect(repo.lastAfter, (createdAt: at, id: 'p15'));
    final items = container.read(pagedPostsProvider(src)).requireValue.items;
    expect(items.length, 25);
    expect(items.map((p) => p.id).toSet().length, 25);
  });

  test('refresh during loadMore wins; loadMore result is discarded', () async {
    await container.read(pagedPostsProvider(src).future);
    final gate = repo.gate = Completer();
    final more = notifier().loadMore();
    repo
      ..gate = null
      ..posts = List.generate(45, (i) => _post(i, prefix: 'n'));
    await notifier().refresh();
    gate.complete();
    await more;
    final page = container.read(pagedPostsProvider(src)).requireValue;
    expect(page.items.length, 20);
    expect(page.items.first.id, 'n0');
    expect(page.loadingMore, isFalse);
  });

  test('an older refresh cannot overwrite a newer one', () async {
    await container.read(pagedPostsProvider(src).future);
    final gate = repo.gate = Completer();
    final older = notifier().refresh();
    repo
      ..gate = null
      ..posts = List.generate(45, (i) => _post(i, prefix: 'n'));
    await notifier().refresh();
    repo.posts = List.generate(45, (i) => _post(i, prefix: 'old'));
    gate.complete();
    await older;
    final page = container.read(pagedPostsProvider(src)).requireValue;
    expect(page.items.first.id, 'n0');
  });

  test('failed loadMore rolls back and rethrows', () async {
    await container.read(pagedPostsProvider(src).future);
    repo.fail = true;
    await expectLater(notifier().loadMore(), throwsException);
    final state = container.read(pagedPostsProvider(src));
    expect(state.hasError, isFalse);
    expect(state.requireValue.items.length, 20);
    expect(state.requireValue.loadingMore, isFalse);
    expect(state.requireValue.hasMore, isTrue);
  });

  group('feed source', () {
    Future<List<String>?> feedAuthors(List<String> following) async {
      final c = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(testUser('me')),
          postRepositoryProvider.overrideWithValue(repo),
          followRepositoryProvider.overrideWithValue(
            FakeFollowRepository(following),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(pagedPostsProvider(PostSource.feed), (_, _) {});
      await c.read(pagedPostsProvider(PostSource.feed).future);
      return repo.lastAuthorIds;
    }

    test('following nobody queries global posts', () async {
      expect(await feedAuthors([]), isNull);
    });

    test('following ids query follows + own id', () async {
      expect((await feedAuthors(['f1', 'f2']))?.toSet(), {'f1', 'f2', 'me'});
    });

    test('loadMore keeps the resolved feed authors', () async {
      final c = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(testUser('me')),
          postRepositoryProvider.overrideWithValue(repo),
          followRepositoryProvider.overrideWithValue(
            FakeFollowRepository(['f1']),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(pagedPostsProvider(PostSource.feed), (_, _) {});
      await c.read(pagedPostsProvider(PostSource.feed).future);
      repo.lastAuthorIds = null;
      await c.read(pagedPostsProvider(PostSource.feed).notifier).loadMore();
      expect(repo.lastAuthorIds?.toSet(), {'f1', 'me'});
    });
  });
}
