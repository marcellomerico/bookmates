import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_config.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/social/providers/paged_posts.dart';
import '../../features/social/providers/social_providers.dart';
import '../../models/post.dart';

Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  String? reportedUserId,
  String? postId,
  String? commentId,
}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Inhalt melden'),
      content: TextField(
        controller: controller,
        maxLength: AppLimits.reportReason,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Warum möchtest du das melden?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Melden'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (reason == null || reason.isEmpty) return;

  final user = ref.read(currentUserProvider);
  if (user == null) return;

  String message;
  try {
    await ref
        .read(moderationRepositoryProvider)
        .reportContent(
          reporterId: user.id,
          reason: reason,
          reportedUserId: reportedUserId,
          postId: postId,
          commentId: commentId,
        );
    message = 'Danke für deine Meldung. Wir prüfen sie zeitnah.';
  } catch (e) {
    message = authErrorMessage(e);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> _blockUser(
  BuildContext context,
  WidgetRef ref, {
  required String blockerId,
  required String blockedId,
  String? postId,
}) async {
  String message = 'Nutzer blockiert.';
  try {
    await ref
        .read(moderationRepositoryProvider)
        .blockUser(blockerId: blockerId, blockedId: blockedId);
    ref.invalidate(pagedPostsProvider);
    if (postId != null) {
      ref.invalidate(commentsProvider(postId));
      ref.invalidate(postDetailProvider(postId));
    }
  } catch (e) {
    message = authErrorMessage(e);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<bool> _confirmDelete(BuildContext context, String title, String body) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Löschen'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<void> showPostActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final isOwner = post.authorId == user.id;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: const Text('Beitrag löschen'),
              onTap: () => Navigator.pop(context, 'delete'),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Beitrag melden'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            if (post.author != null)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(
                  '${post.author!.displayName ?? post.author!.username} blockieren',
                ),
                onTap: () => Navigator.pop(context, 'block'),
              ),
          ],
        ],
      ),
    ),
  );

  if (action == 'delete') {
    if (!context.mounted) return;
    if (!await _confirmDelete(
      context,
      'Beitrag löschen?',
      'Dieser Beitrag wird dauerhaft entfernt.',
    )) {
      return;
    }
    try {
      await ref.read(postRepositoryProvider).deletePost(post.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
      return;
    }
    ref.invalidate(pagedPostsProvider);
    if (context.mounted) {
      if (context.canPop()) context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beitrag gelöscht.')));
    }
  } else if (action == 'report') {
    if (context.mounted) {
      await showReportDialog(
        context,
        ref,
        reportedUserId: post.authorId,
        postId: post.id,
      );
    }
  } else if (action == 'block' && post.author != null && context.mounted) {
    await _blockUser(
      context,
      ref,
      blockerId: user.id,
      blockedId: post.author!.id,
      postId: post.id,
    );
  }
}

Future<void> showUserActionsMenu(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null || user.id == userId) return;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Nutzer melden'),
            onTap: () => Navigator.pop(context, 'report'),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text('$displayName blockieren'),
            onTap: () => Navigator.pop(context, 'block'),
          ),
        ],
      ),
    ),
  );

  if (action == 'report' && context.mounted) {
    await showReportDialog(context, ref, reportedUserId: userId);
  } else if (action == 'block' && context.mounted) {
    await _blockUser(context, ref, blockerId: user.id, blockedId: userId);
  }
}

/// Actions for a single comment: delete (own) or report / block author (others).
Future<void> showCommentActionsMenu(
  BuildContext context,
  WidgetRef ref, {
  required Comment comment,
  required String postId,
  required Future<void> Function() onDelete,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final isOwner = comment.authorId == user.id;
  final authorName = comment.author?.displayName ?? comment.author?.username;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: const Text('Kommentar löschen'),
              onTap: () => Navigator.pop(context, 'delete'),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Kommentar melden'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text('${authorName ?? 'Nutzer'} blockieren'),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ],
      ),
    ),
  );
  if (!context.mounted) return;

  if (action == 'delete') {
    if (!await _confirmDelete(
      context,
      'Kommentar löschen?',
      'Dieser Kommentar wird dauerhaft entfernt.',
    )) {
      return;
    }
    try {
      await onDelete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    }
  } else if (action == 'report') {
    await showReportDialog(
      context,
      ref,
      reportedUserId: comment.authorId,
      commentId: comment.id,
      postId: postId,
    );
  } else if (action == 'block') {
    await _blockUser(
      context,
      ref,
      blockerId: user.id,
      blockedId: comment.authorId,
      postId: postId,
    );
  }
}
