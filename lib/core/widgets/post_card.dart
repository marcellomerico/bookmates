import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/social/providers/social_providers.dart';
import '../../models/post.dart';
import '../theme/app_theme.dart';
import '../theme/bookmates_ui.dart';
import '../utils/time_ago.dart';
import 'moderation_actions.dart';
import 'user_avatar.dart';

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  Future<void> _toggleLike(WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repo = ref.read(postRepositoryProvider);
    try {
      if (post.likedByMe) {
        await repo.unlikePost(postId: post.id, userId: user.id);
      } else {
        await repo.likePost(postId: post.id, userId: user.id);
      }
      ref.invalidate(feedProvider);
      ref.invalidate(postDetailProvider(post.id));
      ref.invalidate(activityProvider);
      if (post.groupId != null) {
        ref.invalidate(groupPostsProvider(post.groupId!));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = post.author;
    final displayName = author?.displayName ?? author?.username ?? 'Leser';
    final handle = author != null ? '@${author.username}' : '';

    return SoftCard(
      child: InkWell(
        onTap: () => context.push('/posts/${post.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: author == null ? null : () => context.push('/users/${author.id}'),
                  child: UserAvatar(url: author?.avatarUrl, name: displayName, radius: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: author == null ? null : () => context.push('/users/${author.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(
                          '$handle • ${formatRelativeTime(post.createdAt)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: AppColors.muted, size: 20),
                  onPressed: () => showPostActionsMenu(context, ref, post),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.content, style: const TextStyle(fontSize: 13, height: 1.45)),
            if (post.book != null) ...[
              const SizedBox(height: 12),
              _BookChip(
                title: post.book!.title,
                author: post.book!.author,
                coverUrl: post.book!.coverUrl,
              ),
            ],
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 180,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: () => _toggleLike(ref),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          post.likedByMe ? Icons.favorite : Icons.favorite_border,
                          size: 17,
                          color: post.likedByMe ? AppColors.burgundy : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text('${post.likeCount}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => context.push('/posts/${post.id}'),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 17, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text('${post.commentCount}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  const _BookChip({required this.title, this.author, this.coverUrl});

  final String title;
  final String? author;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: coverUrl!, width: 42, height: 58, fit: BoxFit.cover),
            )
          else
            Container(
              width: 42,
              height: 58,
              decoration: BoxDecoration(color: AppColors.burgundy, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (author != null)
                  Text(author!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
