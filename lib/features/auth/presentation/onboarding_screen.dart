import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/constants/genres.dart';
import '../../../core/theme/bookmates_ui.dart';
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
            .map((genre) => {'user_id': user.id, 'genre_id': genreMap[genre]})
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
        setState(
          () => _error = 'Onboarding konnte nicht gespeichert werden. $e',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
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
      resizeToAvoidBottomInset: true,
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
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BookmatesWordmark(),
                    const SizedBox(height: 18),
                    _buildStep(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          ],
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
            Text(
              'Erzahl uns etwas\nuber dich.',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Damit wir dir die richtigen Leser und Bucher zeigen konnen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              maxLength: AppLimits.displayName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Anzeigename'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLength: AppLimits.bio,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Kurz über dich'),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Was liest du gern?',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Wahle mindestens ein Genre. Du kannst spater alles andern.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
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
            Text(
              'Dein erstes\nBucherregal.',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Optional: Fuge dein erstes Buch hinzu. Du kannst auch uberspringen und spater weitermachen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _openBookSearch,
              icon: const Icon(Icons.search),
              label: const Text('Buch suchen und hinzufügen'),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 220, child: BookshelfWidget(compact: true)),
          ],
        );
    }
  }
}
