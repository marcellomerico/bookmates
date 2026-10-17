import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post.dart';

class PostRepository {
  PostRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, profiles(*), books(*), likes(user_id), comments(id)';

  Future<Post> createPost({
    required String authorId,
    required String content,
    PostType postType = PostType.discussion,
    String? bookId,
    String? groupId,
    String? imageUrl,
  }) async {
    final inserted = await _client
        .from('posts')
        .insert({
          'author_id': authorId,
          'content': content.trim(),
          'post_type': postType.dbValue,
          'book_id': ?bookId,
          'group_id': ?groupId,
          'image_url': ?imageUrl,
        })
        .select(_select)
        .single();

    return Post.fromJson(inserted, currentUserId: authorId);
  }

  Future<List<Post>> getFeed({
    required String currentUserId,
    List<String>? authorIds,
    String? groupId,
    int limit = 40,
  }) async {
    var query = _client.from('posts').select(_select);

    if (groupId != null) {
      query = query.eq('group_id', groupId);
    } else if (authorIds != null && authorIds.isNotEmpty) {
      query = query
          .inFilter('author_id', authorIds)
          .filter('group_id', 'is', null);
    } else {
      query = query.filter('group_id', 'is', null);
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);

    return (rows as List)
        .map(
          (row) => Post.fromJson(
            row as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<Post?> getPost(String postId, {String? currentUserId}) async {
    final row = await _client
        .from('posts')
        .select(_select)
        .eq('id', postId)
        .maybeSingle();
    if (row == null) return null;
    return Post.fromJson(row, currentUserId: currentUserId);
  }

  Future<List<Post>> getPostsByAuthor(
    String authorId, {
    String? currentUserId,
  }) async {
    final rows = await _client
        .from('posts')
        .select(_select)
        .eq('author_id', authorId)
        .filter('group_id', 'is', null)
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (row) => Post.fromJson(
            row as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<void> deletePost(String postId) async {
    final row = await _client
        .from('posts')
        .select('image_url')
        .eq('id', postId)
        .maybeSingle();
    await _client.from('posts').delete().eq('id', postId);

    final imageUrl = row?['image_url'] as String?;
    if (imageUrl != null) await removePostImage(imageUrl);
  }

  /// Best-effort storage cleanup; never throws.
  Future<void> removePostImage(String url) async {
    final path = postImagePathFromUrl(url);
    if (path == null) return;
    try {
      await _client.storage.from('post-images').remove([path]);
    } catch (e) {
      debugPrint('post image cleanup failed: $e');
    }
  }

  Future<void> likePost({
    required String postId,
    required String userId,
  }) async {
    await _client.from('likes').upsert(
      {'post_id': postId, 'user_id': userId},
      ignoreDuplicates: true,
    );
  }

  Future<void> unlikePost({
    required String postId,
    required String userId,
  }) async {
    await _client
        .from('likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  Future<List<Comment>> getComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select('*, profiles(*)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => Comment.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String content,
  }) async {
    final inserted = await _client
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': authorId,
          'content': content.trim(),
        })
        .select('*, profiles(*)')
        .single();

    return Comment.fromJson(inserted);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  Future<String> uploadPostImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('post-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );

    return _client.storage.from('post-images').getPublicUrl(path);
  }
}

/// Object path inside the 'post-images' bucket for a public URL, or null.
String? postImagePathFromUrl(String url) {
  final segments = Uri.parse(url).pathSegments;
  final i = segments.indexOf('post-images');
  // Bucket segment must follow the storage access mode, e.g. .../object/public/post-images/...
  if (i < 1 || !const {'public', 'sign', 'authenticated'}.contains(segments[i - 1])) {
    return null;
  }
  final path = segments.skip(i + 1).join('/');
  return path.isEmpty ? null : path;
}
