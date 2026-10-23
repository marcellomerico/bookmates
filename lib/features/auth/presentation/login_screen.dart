import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../providers/auth_provider.dart';
import 'social_sign_in_buttons.dart';
import 'terms_links_text.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(_emailController.text.trim(), _passwordController.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: KeyboardSafeScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Center(child: BooksquadWordmark()),
              const SizedBox(height: 28),
              Text(
                'Willkommen\nzurück.',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Deine Community für Bücher und Leser.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _signIn(),
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
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: context.palette.burgundy,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.palette.onBurgundy,
                        ),
                      )
                    : const Text('Anmelden'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Passwort vergessen?'),
              ),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Noch kein Konto? Registrieren'),
              ),
              const SizedBox(height: 10),
              const SocialSignInButtons(compact: true),
              if (SocialSignInButtons.hasAny) ...[
                const SizedBox(height: 12),
                TermsLinksText(
                  before: SocialSignInButtons.termsNoticePrefix,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.palette.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
