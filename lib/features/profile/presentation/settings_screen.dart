import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open(BuildContext context, String url, String label) async {
    if (!await openExternalUrl(url) && context.mounted) {
      _snack(context, '$label: $url');
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (context.mounted) _snack(context, authErrorMessage(e));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    // Captured before the await: the router redirect may dispose this screen.
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repo = ref.read(authRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Konto löschen?'),
        content: const Text(
          'Dein Profil, Beiträge und Daten werden dauerhaft entfernt. Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konto löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repo.deleteAccount();
      container.invalidate(currentProfileProvider);
      container.invalidate(authStateProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Konto wurde gelöscht.')),
      );
      router.go('/login');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    final error = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const _Header('Konto'),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Profil bearbeiten'),
            onTap: () => context.push('/profile/edit'),
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Meldungen prüfen'),
              onTap: () => context.push('/moderation'),
            ),
          const _Header('Hilfe & Rechtliches'),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Support kontaktieren'),
            onTap: () async {
              if (!await openSupportEmail() && context.mounted) {
                _snack(context, 'E-Mail-App konnte nicht geöffnet werden.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Datenschutz'),
            onTap: () =>
                _open(context, AppConfig.privacyPolicyUrl, 'Datenschutz'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Nutzungsbedingungen'),
            onTap: () =>
                _open(context, AppConfig.termsUrl, 'Nutzungsbedingungen'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Impressum'),
            onTap: () => _open(context, AppConfig.imprintUrl, 'Impressum'),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Lizenzen'),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'Booksquad'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Abmelden'),
            onTap: () => _signOut(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: error),
            title: Text('Konto löschen', style: TextStyle(color: error)),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
    ),
  );
}
