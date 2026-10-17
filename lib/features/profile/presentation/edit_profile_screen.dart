import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/constants/genres.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_sanitizer.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _selectedGenres = {};
  bool _loading = false;
  bool _initialized = false;
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_initialized) return;
    final profile = await ref.read(currentProfileProvider.future);
    final genres = await ref.read(userGenresProvider.future);
    if (!mounted || profile == null) return;

    _displayNameController.text = profile.displayName ?? '';
    _bioController.text = profile.bio ?? '';
    _selectedGenres
      ..clear()
      ..addAll(genres);
    setState(() => _initialized = true);
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            userId: user.id,
            displayName: _displayNameController.text,
            bio: _bioController.text,
            genres: _selectedGenres,
          );
      if (_avatarBytes != null) {
        await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(
              userId: user.id,
              bytes: _avatarBytes!,
              contentType: 'image/jpeg',
            );
      }
      ref.invalidate(currentProfileProvider);
      ref.invalidate(userGenresProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil konnte nicht gespeichert werden.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (image == null) return;
    try {
      final bytes = await sanitizeImage(await image.readAsBytes(), maxEdge: 512);
      if (mounted) setState(() => _avatarBytes = bytes);
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bild konnte nicht gelesen werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil bearbeiten'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Profil konnte nicht geladen werden.')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Kein Profil gefunden.'));
          }

          if (!_initialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: Stack(
                  children: [
                    _avatarBytes != null
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: MemoryImage(_avatarBytes!),
                          )
                        : UserAvatar(
                            url: data.avatarUrl,
                            name: data.displayName ?? data.username,
                            radius: 40,
                          ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        onPressed: _loading ? null : _pickAvatar,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _displayNameController,
                maxLength: AppLimits.displayName,
                decoration: const InputDecoration(labelText: 'Anzeigename'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLength: AppLimits.bio,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 24),
              Text(
                'Lieblingsgenres',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Wähle die Genres, die dich am besten beschreiben.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kBookGenres.map((genre) {
                  final selected = _selectedGenres.contains(genre);
                  return FilterChip(
                    label: Text(genre),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedGenres.add(genre);
                        } else {
                          _selectedGenres.remove(genre);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
