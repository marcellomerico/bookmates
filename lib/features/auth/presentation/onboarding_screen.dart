import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/genres.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('profiles').update({
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'onboarding_completed': true,
      }).eq('id', user.id);

      if (_selectedGenres.isNotEmpty) {
        final genreRows = await client.from('genres').select('id, name');
        final genreMap = {
          for (final row in genreRows as List)
            row['name'] as String: row['id'] as String
        };

        await client.from('user_genres').delete().eq('user_id', user.id);
        await client.from('user_genres').insert(
          _selectedGenres
              .where(genreMap.containsKey)
              .map((genre) => {
                    'user_id': user.id,
                    'genre_id': genreMap[genre],
                  })
              .toList(),
        );
      }

      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Onboarding konnte nicht gespeichert werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Einrichtung (${_step + 1}/3)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStep()),
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
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fast geschafft!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Als Nächstes kannst du Bücher zu deinem Regal hinzufügen und anderen Lesern folgen.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
        );
    }
  }
}
