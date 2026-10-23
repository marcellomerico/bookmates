import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/group.dart';
import '../../../models/profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../../../repositories/follow_repository.dart';
import '../../social/providers/social_providers.dart';
import '../../../core/widgets/verified_badge.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.initialQuery});
  final String? initialQuery;
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late final TextEditingController _controller;
  List<Profile>? _userResults;
  List<BookGroup>? _groupResults;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery?.trim().isNotEmpty ?? false) _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _userResults = null;
        _groupResults = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final user = ref.read(currentUserProvider);
      final users = await ref
          .read(profileRepositoryProvider)
          .searchProfiles(query, excludeUserId: user?.id);
      final blocked = user == null
          ? <String>[]
          : await ref
                .read(moderationRepositoryProvider)
                .getBlockedUserIds(user.id);
      final groups = await ref
          .read(groupRepositoryProvider)
          .listGroups(currentUserId: user?.id, query: query);
      if (mounted) {
        setState(() {
          _userResults = users.where((p) => !blocked.contains(p.id)).toList();
          _groupResults = groups;
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _toggleFollow(String userId, bool following) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(followRepositoryProvider);
    try {
      if (following) {
        await repo.unfollow(followerId: user.id, followingId: userId);
      } else {
        await repo.follow(followerId: user.id, followingId: userId);
      }
      ref.invalidate(discoverPeopleProvider);
      ref.invalidate(followStateProvider(userId));
      ref.invalidate(pagedPostsProvider);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(discoverPeopleProvider);
    final groups = ref.watch(groupsProvider(null));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(discoverPeopleProvider);
        ref.invalidate(groupsProvider(null));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text('Entdecken', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Leser oder Lesekreise suchen',
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Suchen',
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (_userResults != null || _groupResults != null) ...[
            Text(
              'Suchergebnisse',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if ((_userResults?.isEmpty ?? true) &&
                (_groupResults?.isEmpty ?? true))
              const Text('Keine Treffer gefunden.'),
            ...?_userResults?.map(
              (profile) =>
                  _PersonRow(profile: profile, onToggleFollow: _toggleFollow),
            ),
            ...?_groupResults?.map(
              (group) => _DiscoverClub(
                name: group.name,
                meta:
                    '${group.memberCount} Mitglieder${group.isPrivate ? ' • Privat' : ''}',
                joined: group.isMember,
                onTap: () => context.push('/groups/${group.id}'),
                onJoin: () async {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  final repo = ref.read(groupRepositoryProvider);
                  try {
                    if (group.isMember) {
                      await repo.leaveGroup(groupId: group.id, userId: user.id);
                    } else {
                      await repo.joinGroup(groupId: group.id, userId: user.id);
                    }
                    ref.invalidate(groupsProvider(null));
                    _search();
                  } catch (e) {
                    _showError(e);
                  }
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
          const _DiscoverSectionTitle('Leser für dich'),
          const SizedBox(height: 10),
          ...people.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (_, _) => [
              ErrorState(
                message: 'Empfehlungen konnten nicht geladen werden.',
                onRetry: () => ref.invalidate(discoverPeopleProvider),
              ),
            ],
            data: (items) => items.isEmpty
                ? const [
                    EmptyState(
                      icon: Icons.people_outline,
                      title: 'Noch keine Empfehlungen',
                      message: 'Schau später noch einmal vorbei.',
                    ),
                  ]
                : items
                      .map(
                        (profile) => _PersonRow(
                          profile: profile,
                          onToggleFollow: _toggleFollow,
                        ),
                      )
                      .toList(),
          ),
          const SizedBox(height: 18),
          const _DiscoverSectionTitle('Lesekreise für dich'),
          const SizedBox(height: 10),
          ...groups.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (_, _) => [
              ErrorState(
                message: 'Lesekreise konnten nicht geladen werden.',
                onRetry: () => ref.invalidate(groupsProvider(null)),
              ),
            ],
            // Circles the user hasn't joined first; joined ones only fill up the rest.
            data: (items) => items
                .where((g) => !g.isMember)
                .followedBy(items.where((g) => g.isMember))
                .take(3)
                .map(
                  (group) => _DiscoverClub(
                    name: group.name,
                    meta:
                        '${group.memberCount} Mitglieder${group.isPrivate ? ' • Privat' : ''}',
                    joined: group.isMember,
                    onTap: () => context.push('/groups/${group.id}'),
                    onJoin: () async {
                      final user = ref.read(currentUserProvider);
                      if (user == null) return;
                      final repo = ref.read(groupRepositoryProvider);
                      try {
                        if (group.isMember) {
                          await repo.leaveGroup(
                            groupId: group.id,
                            userId: user.id,
                          );
                        } else {
                          await repo.joinGroup(
                            groupId: group.id,
                            userId: user.id,
                          );
                        }
                        ref.invalidate(groupsProvider(null));
                      } catch (e) {
                        _showError(e);
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSectionTitle extends StatelessWidget {
  const _DiscoverSectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);
}

class _PersonRow extends ConsumerWidget {
  const _PersonRow({required this.profile, required this.onToggleFollow});

  final Profile profile;
  final Future<void> Function(String userId, bool following) onToggleFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followStateProvider(profile.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        child: InkWell(
          onTap: () => context.push('/users/${profile.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              UserAvatar(
                url: profile.avatarUrl,
                name: profile.displayName ?? profile.username,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName ?? profile.username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        VerifiedBadge(profile: profile, size: 14),
                      ],
                    ),
                    Text(
                      '@${profile.username}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              following.when(
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (state) => TinyPill(
                  onTap: () =>
                      onToggleFollow(profile.id, state != FollowState.none),
                  label: switch (state) {
                    FollowState.following => 'Entfolgen',
                    FollowState.requested => 'Angefragt',
                    FollowState.none => 'Folgen',
                  },
                  filled: state != FollowState.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverClub extends StatelessWidget {
  const _DiscoverClub({
    required this.name,
    required this.meta,
    required this.joined,
    required this.onTap,
    required this.onJoin,
  });

  final String name;
  final String meta;
  final bool joined;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: SoftCard(
          child: Row(
            children: [
              Container(
                width: 38,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      meta,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TinyPill(
                onTap: onJoin,
                label: joined ? 'Verlassen' : 'Beitreten',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
