import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../../../core/utils/image_sanitizer.dart';
import '../../../models/post.dart';
import '../../../models/user_book.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../../social/providers/social_providers.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  PostType _postType = PostType.discussion;
  UserBook? _selectedBook;
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _chooseBook() async {
    final books = await ref.read(bookshelfProvider.future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<UserBook>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          const ListTile(title: Text('Buch aus deinem Regal')),
          ...books
              .where((entry) => entry.book != null)
              .map(
                (entry) => ListTile(
                  title: Text(entry.book!.title),
                  subtitle: Text(entry.book!.author ?? ''),
                  onTap: () => Navigator.pop(context, entry),
                ),
              ),
        ],
      ),
    );
    if (selected != null) setState(() => _selectedBook = selected);
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return;
    try {
      final bytes = await sanitizeImage(await file.readAsBytes());
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bild konnte nicht gelesen werden.')),
      );
    }
  }

  Future<void> _share() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _contentController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await ref
            .read(postRepositoryProvider)
            .uploadPostImage(
              userId: user.id,
              bytes: _imageBytes!,
              contentType: 'image/jpeg',
            );
      }

      final repo = ref.read(postRepositoryProvider);
      try {
        await repo.createPost(
          authorId: user.id,
          content: _contentController.text,
          postType: _postType,
          bookId: _selectedBook?.bookId,
          groupId: widget.groupId,
          imageUrl: imageUrl,
        );
      } catch (_) {
        if (imageUrl != null) await repo.removePostImage(imageUrl);
        rethrow;
      }
      ref.invalidate(pagedPostsProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileStatsProvider(user.id));
      if (widget.groupId != null) {
        ref.invalidate(groupDetailProvider(widget.groupId!));
      }
      if (!mounted) return;
      _contentController.clear();
      setState(() {
        _imageBytes = null;
        _selectedBook = null;
        _postType = PostType.discussion;
      });
      if (widget.groupId != null) {
        context.go('/groups/${widget.groupId}');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRateLimit(e)
                  ? authErrorMessage(e)
                  : 'Beitrag konnte nicht geteilt werden.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Neuer Beitrag',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        if (widget.groupId != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(
                'Wird gepostet in: ${ref.watch(groupDetailProvider(widget.groupId!)).value?.name ?? '…'}',
              ),
              deleteIcon: const Icon(Icons.close, size: 18),
              deleteButtonTooltipMessage: 'Lesekreis entfernen',
              onDeleted: _saving ? null : () => context.go('/create'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _contentController,
                maxLength: AppLimits.postContent,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Was liest du gerade? Teile Gedanken, Zitate oder eine kleine Rezension …',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const Divider(color: AppColors.line),
              const SizedBox(height: 8),
              DropdownButtonFormField<PostType>(
                initialValue: _postType,
                decoration: const InputDecoration(labelText: 'Beitragsart'),
                items: PostType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (type) => setState(() => _postType = type ?? _postType),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _chooseBook,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(_selectedBook?.book?.title ?? 'Buch verknüpfen'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _imageBytes == null ? 'Bild hinzufügen' : 'Bild ersetzen',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _share,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Teilen'),
        ),
      ],
    );
  }
}
