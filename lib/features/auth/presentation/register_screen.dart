import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../../../core/utils/validators.dart';
import '../../books/providers/books_provider.dart';
import '../providers/auth_provider.dart';
import 'social_sign_in_buttons.dart';
import 'terms_links_text.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Bitte alle Felder ausfüllen.');
      return;
    }
    if (!_acceptedTerms) {
      setState(
        () => _error =
            'Bitte akzeptiere die Nutzungsbedingungen und die Datenschutzerklärung.',
      );
      return;
    }
    _usernameController.text = username;
    final usernameError = validateUsername(username);
    if (usernameError != null) {
      setState(() => _error = usernameError);
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Passwort: mindestens 8 Zeichen.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final usernameFree = await ref
          .read(profileRepositoryProvider)
          .isUsernameAvailable(username);
      if (!mounted) return;
      if (!usernameFree) {
        setState(() => _error = 'Dieser Benutzername ist bereits vergeben.');
        return;
      }

      final result = await ref
          .read(authRepositoryProvider)
          .signUp(email, password, username);

      TextInput.finishAutofillContext();
      if (!mounted) return;

      if (result.needsEmailConfirmation) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog.adaptive(
            title: const Text('E-Mail bestätigen'),
            // Supabase answers a repeated signup like a new one (no mail, no
            // hint) to avoid revealing registered addresses, so say both cases.
            content: Text(
              'Wir haben dir eine Bestätigungs-E-Mail an $email geschickt. '
              'Bitte bestätige deine Adresse, bevor du dich anmeldest.\n\n'
              'Keine Mail bekommen? Dann gibt es für diese Adresse vielleicht '
              'schon ein Konto. Melde dich an oder nutze „Passwort vergessen?“.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) context.go('/login');
        return;
      }

      ref.invalidate(currentProfileProvider);
      context.go('/onboarding');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AutofillGroup(
        child: SafeArea(
          child: KeyboardSafeScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BooksquadWordmark()),
                const SizedBox(height: 24),
                Text(
                  'Willkommen\nbei Booksquad.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Erstelle dein Leserprofil und entdecke Menschen mit ähnlichem Geschmack.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Benutzername'),
                  autofillHints: const [AutofillHints.newUsername],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _signUp(),
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Passwort anzeigen'
                          : 'Passwort verbergen',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: const TermsLinksText(
                          before: 'Ich akzeptiere die ',
                          after: '.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _signUp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Konto erstellen'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Zurück zur Anmeldung'),
                ),
                const SizedBox(height: 10),
                const SocialSignInButtons(compact: true),
                if (SocialSignInButtons.hasAny) ...[
                  const SizedBox(height: 12),
                  TermsLinksText(
                    before: SocialSignInButtons.termsNoticePrefix,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
