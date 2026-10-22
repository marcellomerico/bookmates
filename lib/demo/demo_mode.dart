import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/books/providers/books_provider.dart';
import '../features/social/providers/social_providers.dart';
import '../models/activity_item.dart';
import '../models/book.dart';
import '../models/group.dart';
import '../models/moderation_report.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../models/profile_stats.dart';
import '../models/user_book.dart';
import '../repositories/activity_repository.dart';
import '../repositories/book_repository.dart';
import '../repositories/follow_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/moderation_repository.dart';
import '../repositories/open_library_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/profile_repository.dart';
import 'demo_data.dart';
import '../models/verification.dart';
import '../features/books/suggestions.dart';
import '../models/shelf_decor.dart';

/// Demo mode: `flutter run --dart-define=BOOKSQUAD_DEMO=true`. The app runs signed in
/// as a sample reader on in-memory data, without Supabase. Used for screenshots and
/// the trailer; const-false in normal builds, so the compiler drops it.
const kDemoMode = bool.fromEnvironment('BOOKSQUAD_DEMO');

final _store = DemoStore();
// Never contacted: every repository below overrides the methods the screens call.
final _client = SupabaseClient('https://demo.invalid', 'demo');

final _demoUser = User(
  id: DemoStore.meId,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026, 1, 1).toIso8601String(),
  email: 'marie@example.com',
);

List<Override> demoOverrides() => [
  supabaseClientProvider.overrideWithValue(_client),
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      AuthState(
        AuthChangeEvent.initialSession,
        Session(accessToken: 'demo', tokenType: 'bearer', user: _demoUser),
      ),
    ),
  ),
  currentUserProvider.overrideWithValue(_demoUser),
  currentProfileProvider.overrideWith((ref) async => _store.me),
  authRepositoryProvider.overrideWithValue(_DemoAuth(_client)),
  postRepositoryProvider.overrideWithValue(_DemoPosts(_client)),
  followRepositoryProvider.overrideWithValue(_DemoFollows(_client)),
  groupRepositoryProvider.overrideWithValue(_DemoGroups(_client)),
  moderationRepositoryProvider.overrideWithValue(_DemoModeration(_client)),
  activityRepositoryProvider.overrideWithValue(_DemoActivity(_client)),
  bookRepositoryProvider.overrideWithValue(_DemoBooks(_client)),
  profileRepositoryProvider.overrideWithValue(_DemoProfiles(_client)),
  onboardingSuggestionsProvider.overrideWith(
    (ref) async => OnboardingSuggestions(
      people: _store.profiles.values
          .where((p) => p.id != DemoStore.meId)
          .toList(),
      groups: _store.groups
          .where((g) => !g.isPrivate)
          .map((g) => _store.groupView(g, DemoStore.meId))
          .toList(),
    ),
  ),
];

int _ids = 0;
String _newId(String prefix) => '$prefix-new-${_ids++}';

List<Post> _page(
  Iterable<Post> source,
  PostCursor? after,
  int limit,
  String? userId,
) {
  final sorted = source.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final start = after == null
      ? 0
      : sorted.indexWhere((p) => p.id == after.id) + 1;
  return sorted
      .skip(start)
      .take(limit)
      .map((p) => _store.withState(p, userId))
      .toList();
}

class _DemoAuth extends AuthRepository {
  _DemoAuth(super.client);

  @override
  Future<void> signOut() async {}
}

class _DemoPosts extends PostRepository {
  _DemoPosts(super.client);

  @override
  Future<List<Post>> getFeed({
    required String currentUserId,
    List<String>? authorIds,
    String? groupId,
    String? bookId,
    PostCursor? after,
    int limit = 20,
  }) async {
    final source = _store.posts.where((p) {
      if (groupId != null) return p.groupId == groupId;
      if (p.groupId != null) return false;
      if (bookId != null) return p.bookId == bookId;
      return authorIds == null ||
          authorIds.isEmpty ||
          authorIds.contains(p.authorId);
    });
    return _page(source, after, limit, currentUserId);
  }

  @override
  Future<List<Post>> getPostsByAuthor(
    String authorId, {
    String? currentUserId,
    PostCursor? after,
    int limit = 20,
  }) async => _page(
    _store.posts.where((p) => p.authorId == authorId && p.groupId == null),
    after,
    limit,
    currentUserId,
  );

  @override
  Future<Post?> getPost(String postId, {String? currentUserId}) async {
    final p = _store.posts.where((p) => p.id == postId).firstOrNull;
    return p == null ? null : _store.withState(p, currentUserId);
  }

  @override
  Future<Post> createPost({
    required String authorId,
    required String content,
    PostType postType = PostType.discussion,
    String? bookId,
    String? groupId,
    String? imageUrl,
  }) async {
    final post = Post(
      id: _newId('p'),
      authorId: authorId,
      content: content.trim(),
      postType: postType,
      createdAt: DateTime.now(),
      bookId: bookId,
      groupId: groupId,
      imageUrl: imageUrl,
      author: _store.profiles[authorId],
      book: bookId == null ? null : _store.books[bookId],
    );
    _store.posts.add(post);
    return post;
  }

  @override
  Future<void> deletePost(String postId) async =>
      _store.posts.removeWhere((p) => p.id == postId);

  @override
  Future<void> likePost({
    required String postId,
    required String userId,
  }) async => _store.likes.putIfAbsent(postId, () => {}).add(userId);

  @override
  Future<void> unlikePost({
    required String postId,
    required String userId,
  }) async => _store.likes[postId]?.remove(userId);

  @override
  Future<List<Comment>> getComments(String postId) async =>
      List.of(_store.comments[postId] ?? const []);

  @override
  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String content,
  }) async {
    final c = Comment(
      id: _newId('c'),
      postId: postId,
      authorId: authorId,
      content: content.trim(),
      createdAt: DateTime.now(),
      author: _store.profiles[authorId],
    );
    _store.comments.putIfAbsent(postId, () => []).add(c);
    return c;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final list in _store.comments.values) {
      list.removeWhere((c) => c.id == commentId);
    }
  }

  @override
  Future<String> uploadPostImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async => throw UnsupportedError('Bilder-Upload ist im Demo-Modus aus.');
}

class _DemoFollows extends FollowRepository {
  _DemoFollows(super.client);

  Set<String> _of(String id) => _store.following.putIfAbsent(id, () => {});

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async => _of(followerId).contains(followingId);

  @override
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async => _of(followerId).add(followingId);

  @override
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async => _of(followerId).remove(followingId);

  @override
  Future<List<String>> getFollowingIds(String userId) async =>
      _of(userId).toList();

  @override
  Future<List<Profile>> getFollowers(String userId) async => [
    for (final e in _store.following.entries)
      if (e.value.contains(userId)) _store.profiles[e.key]!,
  ];

  @override
  Future<List<Profile>> getFollowing(String userId) async => [
    for (final id in _of(userId)) _store.profiles[id]!,
  ];
}

class _DemoGroups extends GroupRepository {
  _DemoGroups(super.client);

  @override
  Future<List<BookGroup>> listGroups({
    String? currentUserId,
    String? query,
  }) async {
    final q = query?.trim().toLowerCase() ?? '';
    return _store.groups
        .where(
          (g) =>
              !g.isPrivate ||
              (_store.groupMembers[g.id]?.contains(currentUserId) ?? false),
        )
        .where(
          (g) =>
              q.isEmpty ||
              g.name.toLowerCase().contains(q) ||
              (g.description ?? '').toLowerCase().contains(q),
        )
        .map((g) => _store.groupView(g, currentUserId))
        .toList();
  }

  @override
  Future<List<BookGroup>> suggestPublicGroups({
    required String userId,
    required Set<String> genreIds,
    int limit = 5,
  }) async => (await listGroups(
    currentUserId: userId,
  )).where((g) => !g.isPrivate && !g.isMember).take(limit).toList();

  @override
  Future<BookGroup?> getGroup(String groupId, {String? currentUserId}) async {
    final g = _store.groups.where((g) => g.id == groupId).firstOrNull;
    return g == null ? null : _store.groupView(g, currentUserId);
  }

  @override
  Future<BookGroup> createGroup({
    required String creatorId,
    required String name,
    String? description,
    bool isPrivate = false,
  }) async {
    final g = BookGroup(
      id: _newId('g'),
      creatorId: creatorId,
      name: name,
      description: description,
      isPrivate: isPrivate,
      createdAt: DateTime.now(),
      creator: _store.profiles[creatorId],
      inviteCode: isPrivate ? 'DEMO42' : null,
    );
    _store.groups.insert(0, g);
    _store.groupMembers[g.id] = {creatorId};
    return _store.groupView(g, creatorId);
  }

  @override
  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async => _store.groupMembers.putIfAbsent(groupId, () => {}).add(userId);

  @override
  Future<String> joinWithCode(String code) async {
    final g = _store.groups.firstWhere(
      (g) => g.inviteCode == code.trim().toUpperCase(),
      orElse: () => throw Exception('invalid_code'),
    );
    _store.groupMembers[g.id]!.add(DemoStore.meId);
    return g.id;
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async => _store.groupMembers[groupId]?.remove(userId);

  @override
  Future<void> deleteGroup(String groupId) async =>
      _store.groups.removeWhere((g) => g.id == groupId);
}

class _DemoModeration extends ModerationRepository {
  _DemoModeration(super.client);

  @override
  Future<VerificationRequest?> myVerificationRequest() async => null;

  @override
  Future<void> requestVerification({
    required VerificationKind kind,
    required String link,
    String? note,
  }) async {}

  @override
  Future<List<VerificationRequest>> openVerifications() async => const [];

  @override
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {}

  @override
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {}

  @override
  Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async => false;

  @override
  Future<List<String>> getBlockedUserIds(String userId) async => const [];

  @override
  Future<void> reportContent({
    required String reporterId,
    required String reason,
    String? reportedUserId,
    String? postId,
    String? commentId,
  }) async {}

  @override
  Future<bool> isAdmin() async => true;

  @override
  Future<List<ModerationReport>> openReports() async => List.of(_store.reports);

  @override
  Future<void> resolveReport(String reportId, String action) async =>
      _store.reports.removeWhere((r) => r.reportId == reportId);
}

class _DemoActivity extends ActivityRepository {
  _DemoActivity(super.client);

  @override
  Future<List<ActivityItem>> getActivity(
    String userId, {
    int limit = 30,
  }) async => _store.activity.take(limit).toList();
}

class _DemoBooks extends BookRepository {
  _DemoBooks(super.client);

  @override
  Future<Book> upsertFromOpenLibrary(OpenLibraryBook result) async {
    final id = normalizeWorkId(result.openLibraryId);
    final existing = await getByOpenLibraryId(id);
    if (existing != null) return existing;
    final book = Book(
      id: _newId('b'),
      title: result.title,
      author: result.author,
      openLibraryId: id,
      coverUrl: result.coverUrl,
    );
    _store.books[book.id] = book;
    return book;
  }

  @override
  Future<Book?> getByOpenLibraryId(String workId) async => _store.books.values
      .where((b) => b.openLibraryId == normalizeWorkId(workId))
      .firstOrNull;

  @override
  Future<int> readerCount(String bookId) async => _store.shelves.values
      .where((s) => s.any((e) => e.bookId == bookId))
      .length;

  @override
  Future<UserBook?> myEntry({
    required String userId,
    required String bookId,
  }) async =>
      _store.shelves[userId]?.where((e) => e.bookId == bookId).firstOrNull;

  @override
  Future<UserBook> addToShelf({
    required String userId,
    required OpenLibraryBook result,
    required BookStatus status,
  }) async {
    final book = await upsertFromOpenLibrary(result);
    final existing = await myEntry(userId: userId, bookId: book.id);
    if (existing != null) return existing;
    final entry = UserBook(
      id: _newId('ub'),
      userId: userId,
      bookId: book.id,
      status: status,
      book: book,
      pageCount: result.pageCount,
    );
    _store.shelves.putIfAbsent(userId, () => []).add(entry);
    return entry;
  }

  @override
  Future<List<UserBook>> getBookshelf(String userId) async =>
      List.of(_store.shelves[userId] ?? const []);

  UserBook _replace(String id, UserBook Function(UserBook e) change) {
    for (final shelf in _store.shelves.values) {
      final i = shelf.indexWhere((e) => e.id == id);
      if (i >= 0) return shelf[i] = change(shelf[i]);
    }
    throw StateError('unknown shelf entry $id');
  }

  @override
  Future<void> updateStatus(String userBookId, BookStatus status) async =>
      _replace(userBookId, (e) => e.copyWith(status: status));

  @override
  Future<void> updateRating(String userBookId, int? rating) async =>
      _replace(userBookId, (e) => e.copyWith(rating: () => rating));

  @override
  Future<void> updateProgress(
    String userBookId, {
    required int? currentPage,
    required int? pageCount,
    BookStatus? status,
  }) async => _replace(
    userBookId,
    (e) => e.copyWith(
      status: status,
      currentPage: () => currentPage,
      pageCount: () => pageCount,
    ),
  );

  @override
  Future<void> setFavorites(String userId, List<String> userBookIds) async {
    final shelf = _store.shelves[userId] ?? [];
    for (var i = 0; i < shelf.length; i++) {
      final rank = userBookIds.indexOf(shelf[i].id);
      shelf[i] = shelf[i].copyWith(
        favoriteRank: () => rank < 0 ? null : rank + 1,
      );
    }
  }

  final _dismissed = <String>{};

  @override
  Future<List<FriendPick>> friendsFavorites(List<String> userIds) async => [
    for (final id in userIds)
      for (final e in _store.shelves[id] ?? const <UserBook>[])
        if (e.status == BookStatus.read &&
            (e.rating ?? 0) >= 4 &&
            e.book != null)
          FriendPick(
            book: e.book!,
            rating: e.rating!,
            friendName: _store.profiles[id]?.displayName ?? 'Jemand',
          ),
  ];

  @override
  Future<Set<String>> dismissedWorkIds() async => Set.of(_dismissed);

  @override
  Future<void> dismissSuggestion(String workId) async => _dismissed.add(workId);

  @override
  Future<void> removeFromShelf(String userBookId) async {
    for (final shelf in _store.shelves.values) {
      shelf.removeWhere((e) => e.id == userBookId);
    }
  }
}

class _DemoProfiles extends ProfileRepository {
  _DemoProfiles(super.client);

  @override
  Future<void> updateShelfDecor(String userId, List<DecorPiece> decor) async {
    final p = _store.profiles[userId];
    if (p == null) return;
    _store.profiles[userId] = Profile(
      id: p.id,
      username: p.username,
      displayName: p.displayName,
      bio: p.bio,
      avatarUrl: p.avatarUrl,
      onboardingCompleted: p.onboardingCompleted,
      verifiedAt: p.verifiedAt,
      verifiedKind: p.verifiedKind,
      shelfDecor: decor,
    );
  }

  @override
  Future<List<String>> getUserGenreNames(String userId) async =>
      List.of(_store.genres[userId] ?? const []);

  @override
  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
    required Set<String> genres,
    String? username,
  }) async {
    final p = _store.profiles[userId]!;
    _store.profiles[userId] = Profile(
      id: p.id,
      username: username?.trim().toLowerCase() ?? p.username,
      displayName: displayName,
      bio: bio,
      avatarUrl: p.avatarUrl,
      onboardingCompleted: true,
    );
    _store.genres[userId] = genres.toList();
  }

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      !_store.profiles.values.any((p) => p.username == username);

  @override
  Future<Profile?> getProfile(String userId) async => _store.profiles[userId];

  @override
  Future<ProfileStats> getStats(String userId) async => ProfileStats(
    postCount: _store.posts
        .where((p) => p.authorId == userId && p.groupId == null)
        .length,
    followerCount: _store.following.values
        .where((s) => s.contains(userId))
        .length,
    followingCount: _store.following[userId]?.length ?? 0,
  );

  @override
  Future<List<Profile>> searchProfiles(
    String query, {
    String? excludeUserId,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _store.profiles.values
        .where((p) => p.id != excludeUserId)
        .where(
          (p) =>
              p.username.contains(q) ||
              (p.displayName ?? '').toLowerCase().contains(q),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<Profile>> recommendByGenres(
    String userId, {
    int limit = 10,
  }) async {
    final mine = (_store.genres[userId] ?? const <String>[]).toSet();
    final others = _store.profiles.values.where((p) => p.id != userId).toList()
      ..sort(
        (a, b) => (_store.genres[b.id] ?? const [])
            .where(mine.contains)
            .length
            .compareTo(
              (_store.genres[a.id] ?? const []).where(mine.contains).length,
            ),
      );
    return others.take(limit).toList();
  }
}
