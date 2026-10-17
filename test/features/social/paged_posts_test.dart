import 'package:bookmates/features/auth/providers/auth_provider.dart';
import 'package:bookmates/features/social/providers/paged_posts.dart';
import 'package:bookmates/features/social/providers/social_providers.dart';
import 'package:bookmates/models/post.dart';
import 'package:bookmates/repositories/post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

Post _post(int i) => Post(
      id: 'p$i',
      authorId: 'a',
      content: 'post $i',
      postType: PostType.discussion,
      // Newest first: p0 is the most recent.
      createdAt: DateTime.utc(2026, 1, 1).subtract(Duration(minutes: i)),
    );

class FakePostRepository extends PostRepository {
  FakePostRepository(this.posts) : super(offlineClient());

  List<Post> posts;
  int calls = 0;

  /// Applied to `before` before filtering; simulates overlapping pages.
  Duration beforeShift = Duration.zero;

  List<Post> _page(DateTime? before, int limit) => posts
      .where((p) => before == null || p.createdAt.isBefore(before.add(beforeShift)))
      .take(limit)
      .toList();

  @override
  Future<List<Post>> getFeed({
    required String currentUserId,
    List<String>? authorIds,
    String? groupId,
    String? bookId,
    DateTime? before,
    int limit = 20,
  }) async {
    calls++;
    return _page(before, limit);
  }

  @override
  Future<List<Post>> getPostsByAuthor(
    String authorId, {
    String? currentUserId,
    DateTime? before,
    int limit = 20,
  }) async {
    calls++;
    return _page(before, limit);
  }
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
    repo.beforeShift = const Duration(minutes: 3); // next page repeats 3 posts
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
}
