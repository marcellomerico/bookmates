import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/genres.dart';
import '../../../core/theme/app_theme.dart';
import '../../books/presentation/bookshelf_widget.dart';
import '../../books/providers/books_provider.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _selectedGenres = {};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Keine aktive Sitzung. Bitte erneut anmelden.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final displayName = _displayNameController.text.trim();

      final updated = await client
          .from('profiles')
          .update({
            'display_name': displayName.isEmpty ? null : displayName,
            'bio': _bioController.text.trim(),
            'onboarding_completed': true,
          })
          .eq('id', user.id)
          .select()
          .maybeSingle();

      if (updated == null) {
        throw Exception('Profil konnte nicht aktualisiert werden.');
      }

      if (_selectedGenres.isNotEmpty) {
        final genreRows = await client.from('genres').select('id, name');
        final genreMap = {
          for (final row in genreRows as List)
            row['name'] as String: row['id'] as String,
        };

        final rows = _selectedGenres
            .where(genreMap.containsKey)
            .map((genre) => {
                  'user_id': user.id,
                  'genre_id': genreMap[genre],
                })
            .toList();

        await client.from('user_genres').delete().eq('user_id', user.id);
        if (rows.isNotEmpty) {
          await client.from('user_genres').insert(rows);
        }
      }

      ref.invalidate(currentProfileProvider);
      ref.invalidate(userGenresProvider);
      ref.invalidate(bookshelfProvider);
      await ref.read(currentProfileProvider.future);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Onboarding konnte nicht gespeichert werden. $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBookSearch() async {
    await context.push('/books/search?onboarding=true');
    if (mounted) ref.invalidate(bookshelfProvider);
  }

  void _next() {
    setState(() => _error = null);

    if (_step == 0) {
      if (_displayNameController.text.trim().isEmpty) {
        setState(() => _error = 'Bitte gib einen Anzeigenamen ein.');
        return;
      }
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      if (_selectedGenres.isEmpty) {
        setState(() => _error = 'Wähle mindestens ein Genre.');
        return;
      }
      setState(() => _step = 2);
      return;
    }

    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Einrichtung (${_step + 1}/3)'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _error = null;
                          _step--;
                        }),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStep()),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _loading ? null : _next,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_step == 2 ? 'Fertig' : 'Weiter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dein Profil', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Anzeigename'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Kurz über dich'),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lieblingsgenres', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Wähle mindestens ein Genre.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
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
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dein Bücherregal', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Optional: Füge dein erstes Buch hinzu. Du kannst auch überspringen und später Bücher ergänzen.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _openBookSearch,
              icon: const Icon(Icons.search),
              label: const Text('Buch suchen und hinzufügen'),
            ),
            const SizedBox(height: 16),
            const Expanded(child: BookshelfWidget(compact: true)),
          ],
        );
    }
  }
}
