import 'package:booksquad/models/group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookGroup parses aggregate member count', () {
    final group = BookGroup.fromJson({
      'id': 'g1',
      'creator_id': 'u1',
      'name': 'Zirkel',
      'created_at': '2026-10-16T10:00:00Z',
      'group_members': [
        {'count': 7},
      ],
    }, currentUserId: 'u2');

    expect(group.memberCount, 7);
    expect(group.isMember, isFalse);
  });

  test('BookGroup parses invite code and membership', () {
    final group = BookGroup.fromJson({
      'id': 'g1',
      'creator_id': 'u1',
      'name': 'Geheimzirkel',
      'is_private': true,
      'invite_code': 'abc123def0',
      'created_at': '2026-10-16T10:00:00Z',
      'group_members': [
        {'user_id': 'u1'},
        {'user_id': 'u2'},
      ],
    }, currentUserId: 'u2');

    expect(group.inviteCode, 'abc123def0');
    expect(group.memberCount, 2);
    expect(group.isMember, isTrue);
    expect(group.copyWith(isMember: false).inviteCode, 'abc123def0');
  });

  test('BookGroup without invite_code has null inviteCode', () {
    final group = BookGroup.fromJson({
      'id': 'g1',
      'creator_id': 'u1',
      'name': 'Offen',
      'created_at': '2026-10-16T10:00:00Z',
    });
    expect(group.inviteCode, isNull);
  });
}
