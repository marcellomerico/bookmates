String formatRelativeTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final diff = DateTime.now().difference(local);

  if (diff.inSeconds < 60) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
  if (diff.inDays < 7) return 'vor ${diff.inDays} T.';
  return '${local.day}.${local.month}.${local.year}';
}
