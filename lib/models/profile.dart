class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.onboardingCompleted = false,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool onboardingCompleted;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    );
  }
}
