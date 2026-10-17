class ModerationReport {
  const ModerationReport({
    required this.reportId,
    required this.reportedAt,
    required this.reason,
    this.reporterUsername,
    this.targetUserId,
    this.targetUsername,
    this.targetPostId,
    this.targetCommentId,
    this.content,
    this.contentHidden = false,
    this.targetImageUrl,
  });

  final String reportId;
  final DateTime reportedAt;
  final String reason;
  final String? reporterUsername;
  final String? targetUserId;
  final String? targetUsername;
  final String? targetPostId;
  final String? targetCommentId;
  final String? content;
  final bool contentHidden;
  final String? targetImageUrl;

  bool get hasContentTarget => targetPostId != null || targetCommentId != null;

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      reportId: json['report_id'] as String,
      reportedAt: DateTime.parse(json['reported_at'] as String),
      reason: json['reason'] as String,
      reporterUsername: json['reporter_username'] as String?,
      targetUserId: json['target_user_id'] as String?,
      targetUsername: json['target_username'] as String?,
      targetPostId: json['target_post_id'] as String?,
      targetCommentId: json['target_comment_id'] as String?,
      content: json['content'] as String?,
      contentHidden: json['content_hidden'] as bool? ?? false,
      targetImageUrl: json['target_image_url'] as String?,
    );
  }
}
