import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 32),
              Text(
                'Booksquad Setup',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.palette.burgundy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Supabase ist noch nicht konfiguriert. Bitte folge diesen Schritte:',
                style: TextStyle(color: context.palette.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              _Step(
                number: 1,
                title: 'Supabase-Projekt anlegen',
                body:
                    'Erstelle auf supabase.com ein Projekt „booksquad" (Region EU).',
              ),
              _Step(
                number: 2,
                title: 'SQL-Migration ausführen',
                body:
                    'Kopiere supabase/migrations/20260707180000_initial_schema.sql '
                    'in den SQL Editor und führe das Skript aus.',
              ),
              _Step(
                number: 3,
                title: 'E-Mail-Bestätigung deaktivieren',
                body:
                    'Authentication → Providers → Email → „Confirm email" aus (für Tests).',
              ),
              _Step(
                number: 4,
                title: '.env anlegen',
                body:
                    'cp .env.example .env\n'
                    'Trage SUPABASE_URL und SUPABASE_ANON_KEY ein.',
              ),
              _Step(
                number: 5,
                title: 'Social Login (optional)',
                body:
                    'Google: GOOGLE_WEB_CLIENT_ID in .env eintragen, Provider in Supabase '
                    'und Google Cloud aktivieren.\n'
                    'Apple: Provider in Supabase aktivieren, Sign in with Apple in Xcode '
                    '(bereits vorbereitet).',
              ),
              _Step(
                number: 6,
                title: 'App neu starten',
                body:
                    'flutter run — Hot Restart reicht nicht, App komplett neu starten.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: context.palette.burgundy,
            child: Text(
              '$number',
              style: TextStyle(color: context.palette.onBurgundy, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: context.palette.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
