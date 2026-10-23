import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paged_post_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/profile.dart';
import '../../books/presentation/visual_shelf.dart';
import '../../social/providers/paged_posts.dart';
import '../../social/providers/social_providers.dart';
import 'favorite_books.dart';
import '../../../core/widgets/verified_badge.dart';

/// Shared profile page: header (avatar, stats, name, bio, genres, actions)
/// and tabs for shelf, posts and wishlist. Used for the own and other profiles.
class ProfileLayout extends ConsumerWidget {
  const ProfileLayout({
    super.key,
    required this.profile,
    required this.own,
    required this.actions,
    required this.onRefresh,
    this.locked = false,
  });

  final Profile profile;
  final bool own;

  /// Private account the viewer doesn't follow: only the header is shown.
  final bool locked;

  /// Buttons under the bio (edit profile / follow).
  final Widget actions;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelfUserId = own ? null : profile.id;
    if (locked) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Header(profile: profile, own: own, actions: actions),
            const EmptyState(
              icon: Icons.lock_outline,
              title: 'Dieses Konto ist privat',
              message:
                  'Folge diesem Konto, um Regal, Beiträge und Wunschliste zu sehen.',
            ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _Header(profile: profile, own: own, actions: actions),
          ),
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: const SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _TabPage(
              storageKey: 'shelf',
              onRefresh: onRefresh,
              children: [ShelfView(userId: shelfUserId)],
            ),
            Consumer(
              builder: (context, ref, _) => _TabPage(
                storageKey: 'posts',
                onRefresh: onRefresh,
                children: pagedPostListItems(
                  ref,
                  PostSource.author(profile.id),
                  errorMessage: 'Beiträge konnten nicht geladen werden.',
                  empty: EmptyState(
                    icon: Icons.edit_note,
                    title: 'Noch keine Beiträge',
                    message: own ? 'Teile, was du gerade liest.' : null,
                  ),
                ),
              ),
            ),
            _TabPage(
              storageKey: 'wishlist',
              onRefresh: onRefresh,
              children: [WishlistView(userId: shelfUserId)],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.profile,
    required this.own,
    required this.actions,
  });

  final Profile profile;
  final bool own;
  final Widget actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(profileStatsProvider(profile.id)).valueOrNull;
    final genres =
        ref.watch(userGenresByIdProvider(profile.id)).valueOrNull ?? const [];
    final name = profile.displayName?.isNotEmpty == true
        ? profile.displayName!
        : profile.username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(url: profile.avatarUrl, name: name, radius: 40),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(value: stats?.postCount, label: 'Beiträge'),
                    _Stat(
                      value: stats?.followerCount,
                      label: 'Follower',
                      onTap: () =>
                          context.push('/users/${profile.id}/followers'),
                    ),
                    _Stat(
                      value: stats?.followingCount,
                      label: 'Folgt',
                      onTap: () =>
                          context.push('/users/${profile.id}/following'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              VerifiedBadge(profile: profile, size: 18),
            ],
          ),
          Text(
            '@${profile.username}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (profile.bio?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(profile.bio!),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              genres.join(' · '),
              style: const TextStyle(
                color: AppColors.burgundy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          FavoriteBooks(userId: own ? null : profile.id),
          const SizedBox(height: 14),
          actions,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final int? value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value?.toString() ?? '–',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.s),
      onTap: onTap,
      child: child,
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate();

  static const _height = 48.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: TabBar(
          labelColor: AppColors.burgundy,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.burgundy,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          tabs: [
            Tab(text: 'Regal'),
            Tab(text: 'Beiträge'),
            Tab(text: 'Wunschliste'),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

/// One tab's scrollable content below the pinned tab bar.
class _TabPage extends StatelessWidget {
  const _TabPage({
    required this.storageKey,
    required this.onRefresh,
    required this.children,
  });

  final String storageKey;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            key: PageStorageKey(storageKey),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.list(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
