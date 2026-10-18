import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/group.dart';
import '../../../models/profile.dart';
import '../../social/providers/social_providers.dart';
import '../providers/auth_provider.dart';

class FollowSuggestionsStep extends ConsumerStatefulWidget {
  const FollowSuggestionsStep({super.key});

  @override
  ConsumerState<FollowSuggestionsStep> createState() =>
      _FollowSuggestionsStepState();
}

class _FollowSuggestionsStepState extends ConsumerState<FollowSuggestionsStep> {
  final Set<String> _followed = {};
  final Set<String> _joined = {};
  // Ids with a request in flight; taps on them are ignored.
  final Set<String> _pending = {};

  // Optimistic toggle: flip first, revert + SnackBar on error.
  Future<void> _toggle(
    Set<String> set,
    String id,
    Future<void> Function(String userId, bool on) call,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null || !_pending.add(id)) return;
    final on = !set.contains(id);
    setState(() => on ? set.add(id) : set.remove(id));
    try {
      await call(user.id, on);
    } catch (e) {
      if (!mounted) return;
      setState(() => on ? set.remove(id) : set.add(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      _pending.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = ref.watch(onboardingSuggestionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leser, die deinen Geschmack teilen',
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional: Folge ein paar Lesern und tritt Lesekreisen bei. Du kannst das jederzeit ändern.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        suggestions.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorState(
            message: authErrorMessage(e),
            onRetry: () => ref.invalidate(onboardingSuggestionsProvider),
          ),
          data: (data) {
            if (data.isEmpty) {
              return const EmptyState(
                icon: Icons.people_outline,
                title: 'Du bist eine der ersten Personen hier',
                message:
                    'Lade Freunde ein – Booksquad lebt von seiner Community.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in data.people) _personRow(p),
                if (data.groups.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Lesekreise für dich',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  for (final g in data.groups) _groupRow(g),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _personRow(Profile p) {
    final name = (p.displayName?.trim().isNotEmpty ?? false)
        ? p.displayName!
        : p.username;
    final following = _followed.contains(p.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(url: p.avatarUrl, name: name),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('@${p.username}'),
      trailing: _toggleButton(
        following,
        'Folgen',
        'Folge ich',
        () => _toggle(_followed, p.id, (uid, on) {
          final repo = ref.read(followRepositoryProvider);
          return on
              ? repo.follow(followerId: uid, followingId: p.id)
              : repo.unfollow(followerId: uid, followingId: p.id);
        }),
      ),
    );
  }

  Widget _groupRow(BookGroup g) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
      title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${g.memberCount} Mitglieder'),
      trailing: _toggleButton(
        _joined.contains(g.id),
        'Beitreten',
        'Beigetreten',
        () => _toggle(_joined, g.id, (uid, on) {
          final repo = ref.read(groupRepositoryProvider);
          return on
              ? repo.joinGroup(groupId: g.id, userId: uid)
              : repo.leaveGroup(groupId: g.id, userId: uid);
        }),
      ),
    );
  }

  Widget _toggleButton(
    bool on,
    String offLabel,
    String onLabel,
    VoidCallback onPressed,
  ) {
    return on
        ? OutlinedButton(onPressed: onPressed, child: Text(onLabel))
        : FilledButton(onPressed: onPressed, child: Text(offLabel));
  }
}
