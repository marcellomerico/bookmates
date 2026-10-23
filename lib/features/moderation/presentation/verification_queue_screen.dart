import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/verification.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

/// Admin queue: open requests for the verification badge.
class VerificationQueueScreen extends ConsumerStatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  ConsumerState<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState
    extends ConsumerState<VerificationQueueScreen> {
  final _busy = <String>{};

  Future<void> _resolve(VerificationRequest req, bool approve) async {
    setState(() => _busy.add(req.id));
    try {
      await ref
          .read(moderationRepositoryProvider)
          .resolveVerification(req.id, approve: approve);
      ref.invalidate(openVerificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(req.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(openVerificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifizierungen')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(openVerificationsProvider.future),
        child: requests.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(
            message: 'Anträge konnten nicht geladen werden.',
            onRetry: () => ref.invalidate(openVerificationsProvider),
          ),
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.verified_outlined,
                      title: 'Keine offenen Anträge',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final busy = _busy.contains(r.id);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.displayName ?? r.username ?? 'Leser',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '@${r.username ?? '?'} · ${r.kind.label} · ${formatRelativeTime(r.createdAt)}',
                              style: TextStyle(color: context.palette.muted),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => openExternalUrl(r.link),
                              child: Text(
                                r.link,
                                style: TextStyle(
                                  color: context.palette.burgundy,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            if (r.note != null) ...[
                              const SizedBox(height: 8),
                              Text(r.note!),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _resolve(r, false),
                                    child: const Text('Ablehnen'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => _resolve(r, true),
                                    child: const Text('Verifizieren'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
