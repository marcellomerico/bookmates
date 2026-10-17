import 'package:bookmates/core/utils/time_ago.dart';
import 'package:bookmates/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  hiddenAtTests();
  group('PostType', () {
    test('fromDb maps review', () {
      expect(PostType.fromDb('review'), PostType.review);
    });

    test('fromDb defaults to discussion', () {
      expect(PostType.fromDb('unknown'), PostType.discussion);
    });
  });

  group('Post.fromJson', () {
    test('parses like and comment counts', () {
      final post = Post.fromJson({
        'id': 'p1',
        'author_id': 'u1',
        'content': 'Hello',
        'post_type': 'discussion',
        'created_at': '2026-01-01T12:00:00Z',
        'likes': [
          {'user_id': 'u2'},
          {'user_id': 'u1'},
        ],
        'comments': [
          {'id': 'c1'},
        ],
      }, currentUserId: 'u1');

      expect(post.likeCount, 2);
      expect(post.commentCount, 1);
      expect(post.likedByMe, isTrue);
    });
  });

  group('formatRelativeTime', () {
    test('returns gerade eben for recent', () {
      expect(formatRelativeTime(DateTime.now()), 'gerade eben');
    });
  });
}

void hiddenAtTests() {
  group('hidden_at', () {
    test('Post parses hidden_at', () {
      final base = {
        'id': 'p1',
        'author_id': 'u1',
        'content': 'x',
        'post_type': 'discussion',
        'created_at': '2026-01-01T12:00:00Z',
      };
      expect(Post.fromJson(base).hiddenAt, isNull);
      expect(
        Post.fromJson({...base, 'hidden_at': '2026-02-01T00:00:00Z'}).hiddenAt,
        DateTime.utc(2026, 2, 1),
      );
    });

    test('Comment parses hidden_at', () {
      final base = {
        'id': 'c1',
        'post_id': 'p1',
        'author_id': 'u1',
        'content': 'x',
        'created_at': '2026-01-01T12:00:00Z',
      };
      expect(Comment.fromJson(base).hiddenAt, isNull);
      expect(
        Comment.fromJson({
          ...base,
          'hidden_at': '2026-02-01T00:00:00Z',
        }).hiddenAt,
        DateTime.utc(2026, 2, 1),
      );
    });
  });
}
