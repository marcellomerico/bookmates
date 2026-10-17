import 'package:bookmates/models/moderation_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a full row', () {
    final r = ModerationReport.fromJson({
      'report_id': 'r1',
      'reported_at': '2026-10-01T10:00:00Z',
      'reason': 'Spam',
      'reporter_username': 'anna',
      'target_user_id': 'u1',
      'target_username': 'bob',
      'target_post_id': 'p1',
      'target_comment_id': 'c1',
      'content': 'Hello',
      'content_hidden': true,
    });
    expect(r.reportId, 'r1');
    expect(r.reportedAt, DateTime.utc(2026, 10, 1, 10));
    expect(r.reason, 'Spam');
    expect(r.reporterUsername, 'anna');
    expect(r.targetUserId, 'u1');
    expect(r.targetUsername, 'bob');
    expect(r.targetPostId, 'p1');
    expect(r.targetCommentId, 'c1');
    expect(r.content, 'Hello');
    expect(r.contentHidden, isTrue);
    expect(r.hasContentTarget, isTrue);
  });

  test('parses nulls (user-only report)', () {
    final r = ModerationReport.fromJson({
      'report_id': 'r2',
      'reported_at': '2026-10-01T10:00:00Z',
      'reason': 'Beleidigung',
      'reporter_username': null,
      'target_user_id': 'u1',
      'target_username': null,
      'target_post_id': null,
      'target_comment_id': null,
      'content': null,
      'content_hidden': null,
    });
    expect(r.reporterUsername, isNull);
    expect(r.content, isNull);
    expect(r.contentHidden, isFalse);
    expect(r.hasContentTarget, isFalse);
  });
}
