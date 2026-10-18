import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paged_post_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../social/providers/paged_posts.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pagedPostsProvider(PostSource.feed).notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _HomeHeader(onActivity: () => context.push('/activity')),
          const SizedBox(height: 12),
          ...pagedPostListItems(
            ref,
            PostSource.feed,
            errorMessage: 'Feed konnte nicht geladen werden.',
            loading: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            empty: EmptyState(
              icon: Icons.dynamic_feed_outlined,
              title: 'Noch keine Beiträge',
              message: 'Folge Lesern oder starte eine Diskussion.',
              action: FilledButton.icon(
                onPressed: () => context.go('/discover'),
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Leser entdecken'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onActivity});

  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Booksquad',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Aktivität',
          onPressed: onActivity,
          icon: const Icon(
            Icons.favorite_border_rounded,
            size: 26,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
