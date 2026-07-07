import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Gruppen', style: Theme.of(context).textTheme.headlineSmall),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Neu'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: AppColors.burgundy, size: 32),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Noch keine Gruppen', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        'Erstelle eine Gruppe für dein Lieblingsgenre.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
