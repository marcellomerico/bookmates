import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key, this.compact = false});

  final bool compact;

  static bool get hasAny => Env.isGoogleConfigured || Platform.isIOS;

  /// Notice text naming exactly the providers shown, e.g. 'Mit der Anmeldung über Apple akzeptierst du unsere '.
  static String get termsNoticePrefix =>
      socialTermsNoticePrefix(apple: Platform.isIOS, google: Env.isGoogleConfigured);

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  bool _loading = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SocialSignInButtons.hasAny) return const SizedBox.shrink();
    final showApple = Platform.isIOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('oder', style: TextStyle(color: AppColors.muted)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (Env.isGoogleConfigured)
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () => _run(
                    () => ref.read(authRepositoryProvider).signInWithGoogle(),
                  ),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.g_mobiledata, size: 22),
            label: const Text('Mit Google anmelden'),
          ),
        if (showApple) ...[
          if (Env.isGoogleConfigured) const SizedBox(height: 8),
          SignInWithAppleButton(
            text: 'Mit Apple anmelden',
            style: SignInWithAppleButtonStyle.black,
            height: 48,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            onPressed: () {
              if (_loading) return;
              _run(() => ref.read(authRepositoryProvider).signInWithApple());
            },
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

String socialTermsNoticePrefix({required bool apple, required bool google}) {
  final providers = [if (apple) 'Apple', if (google) 'Google'].join(' oder ');
  return 'Mit der Anmeldung über $providers akzeptierst du unsere ';
}
