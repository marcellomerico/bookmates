/// What a verified account is known as; shown in the badge tooltip.
enum VerificationKind {
  reader,
  author,
  blog,
  bookstore;

  String get label => switch (this) {
    VerificationKind.reader => 'Bekannte Leserin / bekannter Leser',
    VerificationKind.author => 'Autorin / Autor',
    VerificationKind.blog => 'Buchblog',
    VerificationKind.bookstore => 'Buchhandlung',
  };

  static VerificationKind? fromDb(String? value) =>
      VerificationKind.values.where((k) => k.name == value).firstOrNull;
}

/// A request for the badge, as the owner or an admin sees it.
class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.kind,
    required this.link,
    required this.createdAt,
    this.note,
    this.status = 'open',
    this.userId,
    this.username,
    this.displayName,
  });

  final String id;
  final VerificationKind kind;
  final String link;
  final String? note;
  final String status;
  final DateTime createdAt;
  final String? userId;
  final String? username;
  final String? displayName;

  /// Row from `verification_requests` (owner) or `admin_open_verifications` (admin).
  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      VerificationRequest(
        id: (json['request_id'] ?? json['id']) as String,
        kind:
            VerificationKind.fromDb(json['kind'] as String?) ??
            VerificationKind.reader,
        link: json['link'] as String,
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.parse(
          (json['requested_at'] ?? json['created_at']) as String,
        ),
        userId: json['user_id'] as String?,
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
      );
}
