import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../social/providers/social_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(feedProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _HomeHeader(
            onSearch: () => context.go('/discover'),
            onActivity: () => context.push('/activity'),
          ),
          const SizedBox(height: 12),
          TextField(
            textInputAction: TextInputAction.search,
            onSubmitted: (query) => context.go('/discover?q=${Uri.encodeComponent(query)}'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Leser, Clubs oder Stichworte suchen',
            ),
          ),
          const SizedBox(height: 16),
          ...feed.when(
            loading: () => const [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
            error: (_, _) => [
              ErrorState(
                message: 'Feed konnte nicht geladen werden.',
                onRetry: () => ref.invalidate(feedProvider),
              ),
            ],
            data: (posts) => posts.isEmpty
                ? const [
                    EmptyState(
                      icon: Icons.dynamic_feed_outlined,
                      title: 'Noch keine Beiträge',
                      message: 'Folge Lesern oder starte eine Diskussion.',
                    ),
                  ]
                : posts
                    .map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(post: post),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSearch, required this.onActivity});

  final VoidCallback onSearch;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Dein Feed', style: Theme.of(context).textTheme.headlineMedium),
        ),
        IconButton(
          onPressed: onSearch,
          icon: const Icon(Icons.search, size: 20, color: AppColors.ink),
        ),
        IconButton(
          onPressed: onActivity,
          icon: const Icon(Icons.notifications_none, size: 20, color: AppColors.ink),
        ),
      ],
    );
  }
}
