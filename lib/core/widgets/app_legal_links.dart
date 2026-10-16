import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';

/// Legal links + support in profile/settings areas.
class AppLegalLinks extends StatelessWidget {
  const AppLegalLinks({super.key});

  Future<void> _open(BuildContext context, String url, String label) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rechtliches', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _open(context, AppConfig.privacyPolicyUrl, 'Datenschutz'),
          child: const Text('Datenschutzerklärung'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _open(context, AppConfig.termsUrl, 'Nutzungsbedingungen'),
          child: const Text('Nutzungsbedingungen'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _open(context, AppConfig.imprintUrl, 'Impressum'),
          child: const Text('Impressum'),
        ),
      ],
    );
  }
}
