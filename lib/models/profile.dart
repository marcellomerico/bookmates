import 'verification.dart';

class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.onboardingCompleted = false,
    this.verifiedAt,
    this.verifiedKind,
    this.isPrivate = false,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool onboardingCompleted;
  final DateTime? verifiedAt;
  final VerificationKind? verifiedKind;

  /// Private accounts show shelf and posts only to accepted followers.
  final bool isPrivate;

  bool get isVerified => verifiedAt != null;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.parse(json['verified_at'] as String),
      verifiedKind: VerificationKind.fromDb(json['verified_kind'] as String?),
      isPrivate: json['is_private'] as bool? ?? false,
    );
  }
}
