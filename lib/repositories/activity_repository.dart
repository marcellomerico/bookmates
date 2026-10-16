import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_item.dart';
import '../models/profile.dart';

class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  Future<List<ActivityItem>> getActivity(String userId, {int limit = 30}) async {
    final items = <ActivityItem>[];

    final myPosts = await _client.from('posts').select('id, content').eq('author_id', userId);
    final postIds = (myPosts as List).map((row) => row['id'] as String).toList();
    final postContent = {
      for (final row in myPosts as List) row['id'] as String: row['content'] as String,
    };

    if (postIds.isNotEmpty) {
      final likes = await _client
          .from('likes')
          .select('created_at, post_id, profiles:user_id(*)')
          .inFilter('post_id', postIds)
          .neq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      for (final row in likes as List) {
        final profileJson = row['profiles'];
        if (profileJson is! Map<String, dynamic>) continue;
        final postId = row['post_id'] as String;
        items.add(
          ActivityItem(
            type: ActivityType.like,
            createdAt: DateTime.parse(row['created_at'] as String),
            actor: Profile.fromJson(profileJson),
            postId: postId,
            postPreview: postContent[postId],
          ),
        );
      }

      final comments = await _client
          .from('comments')
          .select('created_at, post_id, content, profiles!comments_author_id_fkey(*)')
          .inFilter('post_id', postIds)
          .neq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      for (final row in comments as List) {
        final profileJson = row['profiles'];
        if (profileJson is! Map<String, dynamic>) continue;
        items.add(
          ActivityItem(
            type: ActivityType.comment,
            createdAt: DateTime.parse(row['created_at'] as String),
            actor: Profile.fromJson(profileJson),
            postId: row['post_id'] as String?,
            postPreview: row['content'] as String?,
          ),
        );
      }
    }

    final follows = await _client
        .from('follows')
        .select('created_at, profiles:follower_id(*)')
        .eq('following_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    for (final row in follows as List) {
      final profileJson = row['profiles'];
      if (profileJson is! Map<String, dynamic>) continue;
      items.add(
        ActivityItem(
          type: ActivityType.follow,
          createdAt: DateTime.parse(row['created_at'] as String),
          actor: Profile.fromJson(profileJson),
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(limit).toList();
  }
}
