import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/constants/genres.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_sanitizer.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/social_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _UsernameState { unchanged, checking, available, taken, invalid }

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  String _originalUsername = '';
  _UsernameState _usernameState = _UsernameState.unchanged;
  Timer? _usernameDebounce;
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
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_initialized) return;
    final profile = await ref.read(currentProfileProvider.future);
    final genres = await ref.read(userGenresProvider.future);
    if (!mounted || profile == null) return;

    _originalUsername = profile.username;
    _usernameController.text = profile.username;
    _displayNameController.text = profile.displayName ?? '';
    _bioController.text = profile.bio ?? '';
    _selectedGenres
      ..clear()
      ..addAll(genres);
    setState(() => _initialized = true);
  }

  String get _username => _usernameController.text.trim().toLowerCase();

  void _onUsernameChanged(String _) {
    _usernameDebounce?.cancel();
    final value = _username;
    if (value == _originalUsername) {
      setState(() => _usernameState = _UsernameState.unchanged);
      return;
    }
    if (validateUsername(value) != null) {
      setState(() => _usernameState = _UsernameState.invalid);
      return;
    }
    setState(() => _usernameState = _UsernameState.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      final available = await ref
          .read(profileRepositoryProvider)
          .isUsernameAvailable(value)
          .catchError((_) => false);
      // Ignore answers for a value the user has typed past meanwhile.
      if (!mounted || value != _username) return;
      setState(
        () => _usernameState = available
            ? _UsernameState.available
            : _UsernameState.taken,
      );
    });
  }

  String? get _usernameError => switch (_usernameState) {
    _UsernameState.invalid => validateUsername(_username),
    _UsernameState.taken => 'Dieser Benutzername ist schon vergeben.',
    _ => null,
  };

  String? get _usernameHelper => switch (_usernameState) {
    _UsernameState.checking => 'Wird geprüft …',
    _UsernameState.available => 'Verfügbar',
    _UsernameState.unchanged => 'Eindeutig und für alle sichtbar.',
    _ => null,
  };

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final usernameChanged = _username != _originalUsername;
    if (usernameChanged && _usernameState != _UsernameState.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _usernameError ??
                'Benutzername wird noch geprüft. Bitte kurz warten.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            userId: user.id,
            displayName: _displayNameController.text,
            bio: _bioController.text,
            genres: _selectedGenres,
            username: usernameChanged ? _username : null,
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
      ref.invalidate(userGenresByIdProvider(user.id));
      ref.invalidate(profileByIdProvider(user.id));
      if (mounted) context.pop();
    } on PostgrestException catch (e) {
      // 23505: someone took the name between the check and saving.
      if (mounted) {
        if (e.code == '23505') {
          setState(() => _usernameState = _UsernameState.taken);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == '23505'
                  ? 'Dieser Benutzername ist schon vergeben.'
                  : 'Profil konnte nicht gespeichert werden.',
            ),
          ),
        );
      }
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
      final bytes = await sanitizeImage(
        await image.readAsBytes(),
        maxEdge: 512,
      );
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
                  clipBehavior: Clip.none,
                  children: [
                    _avatarBytes != null
                        ? CircleAvatar(
                            radius: 48,
                            backgroundImage: MemoryImage(_avatarBytes!),
                          )
                        : UserAvatar(
                            url: data.avatarUrl,
                            name: data.displayName ?? data.username,
                            radius: 48,
                          ),
                    // Small badge on the rim so the initial/photo stays visible.
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: IconButton.filled(
                        tooltip: 'Profilbild ändern',
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                        onPressed: _loading ? null : _pickAvatar,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                maxLength: 24,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.username],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                  _LowerCaseFormatter(),
                ],
                onChanged: _onUsernameChanged,
                decoration: InputDecoration(
                  labelText: 'Benutzername',
                  prefixText: '@',
                  errorText: _usernameError,
                  helperText: _usernameHelper,
                  suffixIcon: switch (_usernameState) {
                    _UsernameState.checking => const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    _UsernameState.available => const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      semanticLabel: 'Verfügbar',
                    ),
                    _ => null,
                  },
                ),
              ),
              const SizedBox(height: 12),
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

class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toLowerCase());
}
