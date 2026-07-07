import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dein Feed', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Hier erscheinen Beiträge von Lesern, denen du folgst.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        const _PlaceholderCard(
          icon: Icons.menu_book_outlined,
          title: 'Noch keine Beiträge',
          subtitle: 'Folge anderen Lesern oder tritt einer Gruppe bei.',
        ),
      ],
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: AppColors.burgundy, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
