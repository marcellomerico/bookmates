import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_ago.dart';
import '../../../models/moderation_report.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  final _busy = <String>{};

  Future<void> _resolve(ModerationReport report, String action) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Inhalt löschen?'),
          content: const Text('Der gemeldete Inhalt wird dauerhaft entfernt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy.add(report.reportId));
    // Captured before the await: invalidation must still happen if the admin leaves the screen.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container
          .read(moderationRepositoryProvider)
          .resolveReport(report.reportId, action);
      // Deleted posts must not leave their image publicly reachable (best effort).
      final imageUrl = report.targetImageUrl;
      if (action == 'delete' && imageUrl != null) {
        await container.read(postRepositoryProvider).removePostImage(imageUrl);
      }
      container.invalidate(openReportsProvider);
      container.invalidate(feedProvider);
      container.invalidate(activityProvider);
      final postId = report.targetPostId;
      if (postId != null) {
        container.invalidate(postDetailProvider(postId));
        container.invalidate(commentsProvider(postId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(report.reportId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(openReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meldungen')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(openReportsProvider);
          await ref
              .read(openReportsProvider.future)
              .catchError((_) => <ModerationReport>[]);
        },
        child: reports.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 120),
              const Text(
                'Meldungen konnten nicht geladen werden.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(openReportsProvider),
                  child: const Text('Erneut versuchen'),
                ),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Keine offenen Meldungen',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _ReportCard(
                    report: items[i],
                    busy: _busy.contains(items[i].reportId),
                    onAction: (action) => _resolve(items[i], action),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onAction,
  });

  final ModerationReport report;
  final bool busy;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final muted = const TextStyle(color: AppColors.muted, fontSize: 12);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.reason,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'gemeldet von @${report.reporterUsername ?? '?'} · ${formatRelativeTime(report.reportedAt)}',
              style: muted,
            ),
            const SizedBox(height: 8),
            Text(
              '@${report.targetUsername ?? '?'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (report.hasContentTarget)
              Text(
                report.content ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text('Profil gemeldet', style: muted),
            if (report.contentHidden) ...[
              const SizedBox(height: 6),
              Text(
                'ausgeblendet',
                style: muted.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: report.hasContentTarget
                  ? [
                      TextButton(
                        onPressed: busy ? null : () => onAction('dismiss'),
                        child: const Text('Verwerfen'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => onAction('hide'),
                        child: const Text('Ausblenden'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => onAction('delete'),
                        child: const Text(
                          'Löschen',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: busy ? null : () => onAction('dismiss'),
                        child: const Text('Erledigt'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
