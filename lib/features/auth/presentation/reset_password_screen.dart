import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'Mindestens 8 Zeichen.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Die Passwörter stimmen nicht überein.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(password);
      // Clearing the flag lets the router redirect to /home.
      ref.read(passwordRecoveryProvider.notifier).done();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Passwort')),
      body: AutofillGroup(
        child: SafeArea(
          child: KeyboardSafeScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Neues Passwort festlegen',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Neues Passwort'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Passwort wiederholen',
                  ),
                  onSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: context.palette.burgundy,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.palette.onBurgundy,
                          ),
                        )
                      : const Text('Speichern'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
