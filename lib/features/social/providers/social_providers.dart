import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/activity_item.dart';
import '../../../models/group.dart';
import '../../../models/moderation_report.dart';
import '../../../models/post.dart';
import '../../../models/profile.dart';
import '../../../models/profile_stats.dart';
import '../../../repositories/activity_repository.dart';
import '../../../repositories/follow_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../../repositories/moderation_repository.dart';
import '../../../repositories/post_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(supabaseClientProvider));
});

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(supabaseClientProvider));
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(ref.watch(supabaseClientProvider));
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(supabaseClientProvider));
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});

Future<List<Post>> _filterBlockedPosts(
  Ref ref,
  String userId,
  List<Post> posts,
) async {
  final blocked = await ref
      .read(moderationRepositoryProvider)
      .getBlockedUserIds(userId);
  if (blocked.isEmpty) return posts;
  return posts.where((post) => !blocked.contains(post.authorId)).toList();
}

final feedProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final followRepo = ref.watch(followRepositoryProvider);
  final postRepo = ref.watch(postRepositoryProvider);
  final followingIds = await followRepo.getFollowingIds(user.id);
  final authorIds = {...followingIds, user.id}.toList();

  List<Post> posts;
  if (followingIds.isNotEmpty) {
    posts = await postRepo.getFeed(
      currentUserId: user.id,
      authorIds: authorIds,
    );
  } else {
    posts = await postRepo.getFeed(currentUserId: user.id);
  }

  return _filterBlockedPosts(ref, user.id, posts);
});

final userPostsProvider = FutureProvider.autoDispose.family<List<Post>, String>(
  (ref, userId) async {
    final current = ref.watch(currentUserProvider);
    final posts = await ref
        .watch(postRepositoryProvider)
        .getPostsByAuthor(userId, currentUserId: current?.id);
    if (current == null) return posts;
    return _filterBlockedPosts(ref, current.id, posts);
  },
);

final activityProvider = FutureProvider.autoDispose<List<ActivityItem>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(activityRepositoryProvider).getActivity(user.id);
});

final postDetailProvider = FutureProvider.autoDispose.family<Post?, String>((
  ref,
  postId,
) async {
  final user = ref.watch(currentUserProvider);
  return ref
      .watch(postRepositoryProvider)
      .getPost(postId, currentUserId: user?.id);
});

final commentsProvider = FutureProvider.autoDispose
    .family<List<Comment>, String>((ref, postId) {
      return ref.watch(postRepositoryProvider).getComments(postId);
    });

final profileByIdProvider = FutureProvider.autoDispose.family<Profile?, String>(
  (ref, userId) {
    return ref.watch(profileRepositoryProvider).getProfile(userId);
  },
);

final profileStatsProvider = FutureProvider.autoDispose
    .family<ProfileStats, String>((ref, userId) {
      return ref.watch(profileRepositoryProvider).getStats(userId);
    });

final userGenresByIdProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, userId) {
      return ref.watch(profileRepositoryProvider).getUserGenreNames(userId);
    });

final isFollowingProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  targetUserId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.id == targetUserId) return false;
  return ref
      .watch(followRepositoryProvider)
      .isFollowing(followerId: user.id, followingId: targetUserId);
});

final isBlockedProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  targetUserId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref
      .watch(moderationRepositoryProvider)
      .isBlocked(blockerId: user.id, blockedId: targetUserId);
});

final followersProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, userId) {
      return ref.watch(followRepositoryProvider).getFollowers(userId);
    });

final followingProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, userId) {
      return ref.watch(followRepositoryProvider).getFollowing(userId);
    });

final discoverPeopleProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final blocked = await ref
      .read(moderationRepositoryProvider)
      .getBlockedUserIds(user.id);
  final people = await ref
      .watch(profileRepositoryProvider)
      .recommendByGenres(user.id);
  return people.where((p) => !blocked.contains(p.id)).toList();
});

final groupsProvider = FutureProvider.autoDispose
    .family<List<BookGroup>, String?>((ref, query) async {
      final user = ref.watch(currentUserProvider);
      return ref
          .watch(groupRepositoryProvider)
          .listGroups(currentUserId: user?.id, query: query);
    });

final groupDetailProvider = FutureProvider.autoDispose
    .family<BookGroup?, String>((ref, groupId) async {
      final user = ref.watch(currentUserProvider);
      return ref
          .watch(groupRepositoryProvider)
          .getGroup(groupId, currentUserId: user?.id);
    });

final groupPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, groupId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return [];
      final posts = await ref
          .watch(postRepositoryProvider)
          .getFeed(currentUserId: user.id, groupId: groupId);
      return _filterBlockedPosts(ref, user.id, posts);
    });

// autoDispose: a transient failure (cached as false) is retried when the profile is reopened.
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  try {
    return await ref.watch(moderationRepositoryProvider).isAdmin();
  } catch (_) {
    return false;
  }
});

final openReportsProvider = FutureProvider.autoDispose<List<ModerationReport>>((
  ref,
) {
  return ref.watch(moderationRepositoryProvider).openReports();
});
