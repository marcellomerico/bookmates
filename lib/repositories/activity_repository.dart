import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_item.dart';
import '../models/profile.dart';

class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  Future<List<ActivityItem>> getActivity(String userId, {int limit = 30}) async {
    final items = <ActivityItem>[];

    final results = await Future.wait([
      _client
          .from('likes')
          .select('created_at, post_id, profiles:user_id(*), posts!inner(author_id, content)')
          .eq('posts.author_id', userId)
          .neq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit),
      _client
          .from('comments')
          .select('created_at, post_id, content, profiles!comments_author_id_fkey(*), posts!inner(author_id)')
          .eq('posts.author_id', userId)
          .neq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(limit),
      _client
          .from('follows')
          .select('created_at, profiles:follower_id(*)')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .limit(limit),
    ]);
    final likes = results[0] as List;
    final comments = results[1] as List;
    final follows = results[2] as List;

    for (final row in likes) {
      final profileJson = row['profiles'];
      if (profileJson is! Map<String, dynamic>) continue;
      final post = row['posts'];
      items.add(
        ActivityItem(
          type: ActivityType.like,
          createdAt: DateTime.parse(row['created_at'] as String),
          actor: Profile.fromJson(profileJson),
          postId: row['post_id'] as String,
          postPreview: post is Map ? post['content'] as String? : null,
        ),
      );
    }

    for (final row in comments) {
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

    for (final row in follows) {
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
