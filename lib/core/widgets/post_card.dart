import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/social/providers/like_overrides.dart';
import '../../models/post.dart';
import '../../repositories/open_library_repository.dart';
import '../theme/app_theme.dart';
import '../theme/booksquad_ui.dart';
import '../utils/time_ago.dart';
import 'moderation_actions.dart';
import 'user_avatar.dart';
import 'verified_badge.dart';

int _memWidth(BuildContext context, double logical, int cap) =>
    (logical * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, cap);

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(likeOverridesProvider.notifier)
          .toggle(post, userId: user.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = post.author;
    final displayName = author?.displayName ?? author?.username ?? 'Leser';
    final handle = author != null ? '@${author.username}' : '';
    final like =
        ref.watch(likeOverridesProvider)[post.id] ??
        (liked: post.likedByMe, count: post.likeCount);

    return SoftCard(
      child: InkWell(
        onTap: () => context.push('/posts/${post.id}'),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: author == null
                      ? null
                      : () => context.push('/users/${author.id}'),
                  customBorder: const CircleBorder(),
                  child: UserAvatar(
                    url: author?.avatarUrl,
                    name: displayName,
                    radius: 20,
                    semanticLabel: 'Profil von $displayName',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: author == null
                        ? null
                        : () => context.push('/users/${author.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            VerifiedBadge(profile: author, size: 15),
                          ],
                        ),
                        // Long handles get cut, the time always stays readable.
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                handle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.palette.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              ' · ${formatRelativeTime(post.createdAt)}',
                              maxLines: 1,
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Optionen',
                  icon: Icon(
                    Icons.more_horiz,
                    color: context.palette.muted,
                    size: 20,
                  ),
                  onPressed: () => showPostActionsMenu(context, ref, post),
                ),
              ],
            ),
            if (post.hiddenAt != null) ...[
              const SizedBox(height: 8),
              const HiddenContentHint(),
            ],
            const SizedBox(height: 12),
            _TypeLabel(post.postType),
            const SizedBox(height: 6),
            post.postType == PostType.quote
                ? _QuoteText(post.content)
                : Text(
                    post.content,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
            if (post.book != null) ...[
              const SizedBox(height: 12),
              _BookChip(
                title: post.book!.title,
                author: post.book!.author,
                coverUrl: post.book!.coverUrl,
                onTap: post.book!.openLibraryId == null
                    ? null
                    : () => context.push(
                        '/books/${normalizeWorkId(post.book!.openLibraryId!)}',
                      ),
              ),
            ],
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Semantics(
                  image: true,
                  label: 'Bild zum Beitrag',
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    memCacheWidth: _memWidth(
                      context,
                      MediaQuery.sizeOf(context).width,
                      1080,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Semantics(
                  button: true,
                  toggled: like.liked,
                  label: 'Gefällt mir, ${like.count}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _toggleLike(context, ref),
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Row(
                          children: [
                            Icon(
                              like.liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 22,
                              color: like.liked
                                  ? context.palette.burgundy
                                  : context.palette.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${like.count}',
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Kommentare, ${post.commentCount}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => context.push('/posts/${post.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 22,
                              color: context.palette.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.commentCount}',
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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
  const _BookChip({
    required this.title,
    this.author,
    this.coverUrl,
    this.onTap,
  });

  final String title;
  final String? author;
  final String? coverUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: coverUrl!,
                width: 42,
                height: 58,
                fit: BoxFit.cover,
                memCacheWidth: _memWidth(context, 42, 300),
              ),
            )
          else
            Container(
              width: 42,
              height: 58,
              decoration: BoxDecoration(
                color: context.palette.burgundy,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.menu_book_rounded,
                color: context.palette.onBurgundy,
                size: 18,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (author != null)
                  Text(
                    author!,
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: 'Buchdetails öffnen: $title',
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}

/// Shown to the author when moderation hid their content.
class HiddenContentHint extends StatelessWidget {
  const HiddenContentHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.visibility_off, size: 14, color: context.palette.muted),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Ausgeblendet nach Meldungen – nur für dich sichtbar',
            style: TextStyle(color: context.palette.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Small caps label for the post type (Rezension, Zitat, …).
class _TypeLabel extends StatelessWidget {
  const _TypeLabel(this.type);
  final PostType type;

  @override
  Widget build(BuildContext context) => Text(
    type.label.toUpperCase(),
    style: TextStyle(
      color: context.palette.burgundy,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
}

/// Quotes read like a passage from the book: serif, italic, rule on the left.
class _QuoteText extends StatelessWidget {
  const _QuoteText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: context.palette.gold, width: 3)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'SourceSerif4',
        fontStyle: FontStyle.italic,
        fontSize: 17,
        height: 1.45,
        color: context.palette.ink,
      ),
    ),
  );
}
