import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/moderation_actions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../../social/providers/social_providers.dart';
import '../../../core/widgets/verified_badge.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _commentController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .addComment(
            postId: widget.postId,
            authorId: user.id,
            content: _commentController.text,
          );
      _commentController.clear();
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
      ref.invalidate(pagedPostsProvider);
      ref.invalidate(activityProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRateLimit(e)
                  ? authErrorMessage(e)
                  : 'Kommentar konnte nicht gesendet werden.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await ref.read(postRepositoryProvider).deleteComment(commentId);
    ref.invalidate(commentsProvider(widget.postId));
    ref.invalidate(postDetailProvider(widget.postId));
    ref.invalidate(pagedPostsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(postDetailProvider(widget.postId));
    final comments = ref.watch(commentsProvider(widget.postId));

    final postAsync = ref.watch(postDetailProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitrag'),
        actions: [
          if (postAsync.hasValue && postAsync.value != null)
            IconButton(
              tooltip: 'Optionen',
              icon: const Icon(Icons.more_horiz),
              onPressed: () =>
                  showPostActionsMenu(context, ref, postAsync.value!),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(postDetailProvider(widget.postId));
                ref.invalidate(commentsProvider(widget.postId));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  post.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) =>
                        const Text('Beitrag konnte nicht geladen werden.'),
                    data: (value) => value == null
                        ? const Text('Beitrag nicht gefunden.')
                        : PostCard(post: value),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kommentare',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...comments.when(
                    loading: () => const [
                      Center(child: CircularProgressIndicator()),
                    ],
                    error: (_, _) => const [
                      Text('Kommentare konnten nicht geladen werden.'),
                    ],
                    data: (items) => items.isEmpty
                        ? [
                            Text(
                              'Noch keine Kommentare.',
                              style: TextStyle(color: context.palette.muted),
                            ),
                          ]
                        : items.map((comment) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: comment.author == null
                                    ? null
                                    : () => context.push(
                                        '/users/${comment.author!.id}',
                                      ),
                                child: UserAvatar(
                                  url: comment.author?.avatarUrl,
                                  name:
                                      comment.author?.displayName ??
                                      comment.author?.username,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      comment.author?.displayName ??
                                          comment.author?.username ??
                                          'Leser',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  VerifiedBadge(profile: comment.author),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (comment.hiddenAt != null)
                                    const HiddenContentHint(),
                                  Text(comment.content),
                                  Text(
                                    formatRelativeTime(comment.createdAt),
                                    style: TextStyle(
                                      color: context.palette.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                tooltip: 'Optionen',
                                icon: const Icon(Icons.more_horiz, size: 20),
                                onPressed: () => showCommentActionsMenu(
                                  context,
                                  ref,
                                  comment: comment,
                                  postId: widget.postId,
                                  onDelete: () => _deleteComment(comment.id),
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLength: AppLimits.comment,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Kommentar schreiben …',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kommentar senden',
                    onPressed: _sending ? null : _sendComment,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
