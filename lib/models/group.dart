import 'profile.dart';

class BookGroup {
  const BookGroup({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.isPrivate,
    required this.createdAt,
    this.description,
    this.genreId,
    this.memberCount = 0,
    this.isMember = false,
    this.creator,
    this.inviteCode,
  });

  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final String? genreId;
  final bool isPrivate;
  final DateTime createdAt;
  final int memberCount;
  final bool isMember;
  final Profile? creator;
  final String? inviteCode;

  BookGroup copyWith({int? memberCount, bool? isMember}) {
    return BookGroup(
      id: id,
      creatorId: creatorId,
      name: name,
      description: description,
      genreId: genreId,
      isPrivate: isPrivate,
      createdAt: createdAt,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      creator: creator,
      inviteCode: inviteCode,
    );
  }

  factory BookGroup.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final creatorJson = json['profiles'];
    final members = json['group_members'];

    var memberCount = 0;
    var isMember = false;
    if (members is List) {
      memberCount = members.length;
      if (currentUserId != null) {
        isMember = members.any(
          (row) => row is Map && row['user_id'] == currentUserId,
        );
      }
    } else if (json['member_count'] is int) {
      memberCount = json['member_count'] as int;
      isMember = json['is_member'] as bool? ?? false;
    }

    return BookGroup(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      genreId: json['genre_id'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: memberCount,
      isMember: isMember,
      creator: creatorJson is Map<String, dynamic>
          ? Profile.fromJson(creatorJson)
          : null,
      inviteCode: json['invite_code'] as String?,
    );
  }
}
