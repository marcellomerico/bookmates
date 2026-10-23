import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/verification.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

/// Request the verification badge (known readers, authors, book blogs, bookshops).
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  VerificationKind? _kind;
  final _link = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final link = _link.text.trim();
    final uri = Uri.tryParse(link);
    if (_kind == null) {
      return setState(
        () => _error = 'Bitte wähle aus, als was du bekannt bist.',
      );
    }
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return setState(
        () => _error = 'Bitte gib einen vollständigen Link an (https://…).',
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(moderationRepositoryProvider)
          .requestVerification(
            kind: _kind!,
            link: link,
            note: _note.text.trim(),
          );
      ref.invalidate(myVerificationProvider);
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified =
        ref.watch(currentProfileProvider).valueOrNull?.isVerified ?? false;
    final request = ref.watch(myVerificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifizieren lassen')),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Status konnte nicht geladen werden.',
          onRetry: () => ref.invalidate(myVerificationProvider),
        ),
        data: (req) {
          if (verified) {
            return const _Status(
              icon: Icons.verified,
              title: 'Du bist verifiziert',
              text: 'Neben deinem Namen erscheint der Haken.',
            );
          }
          if (req?.status == 'open') {
            return const _Status(
              icon: Icons.hourglass_top,
              title: 'Antrag wird geprüft',
              text:
                  'Wir schauen uns deinen Nachweis an und melden uns per Mail.',
            );
          }
          return _form(rejected: req?.status == 'rejected');
        },
      ),
    );
  }

  Widget _form({required bool rejected}) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Der Haken zeigt, dass ein Konto wirklich zu einer bekannten Person oder Stelle gehört. '
        'Er ist für bekannte Leserinnen und Leser, Autorinnen und Autoren, Buchblogs und Buchhandlungen gedacht.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      if (rejected) ...[
        const SizedBox(height: 12),
        Text(
          'Dein letzter Antrag wurde abgelehnt. Du kannst einen neuen mit einem anderen Nachweis stellen.',
          style: TextStyle(color: context.palette.muted),
        ),
      ],
      const SizedBox(height: 20),
      Text(
        'Ich bin bekannt als',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      RadioGroup<VerificationKind>(
        groupValue: _kind,
        onChanged: (k) => setState(() {
          _kind = k;
          _error = null;
        }),
        child: Column(
          children: [
            for (final kind in VerificationKind.values)
              RadioListTile<VerificationKind>(
                value: kind,
                title: Text(kind.label),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _link,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Link als Nachweis',
          hintText: 'z. B. Instagram, Blog, Verlags- oder Ladenseite',
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _note,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Anmerkung (optional)'),
      ),
      Text(
        'Bitte keine Ausweisdokumente. Wir speichern nur den Link und deine Anmerkung.',
        style: TextStyle(color: context.palette.muted, fontSize: 13),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: const Text('Antrag senden'),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: icon, title: title, message: text);
}
