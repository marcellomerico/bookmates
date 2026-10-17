import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key, this.compact = false});

  final bool compact;

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
        if (!Env.isGoogleConfigured) ...[
          const SizedBox(height: 8),
          Text(
            'GOOGLE_WEB_CLIENT_ID in .env eintragen.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        if (showApple) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () => _run(
                    () => ref.read(authRepositoryProvider).signInWithApple(),
                  ),
            icon: const Icon(Icons.apple, size: 20),
            label: const Text('Mit Apple anmelden'),
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
