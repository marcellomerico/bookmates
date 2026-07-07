import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Entdecken', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('Finde Leser und Gruppen nach Genre.', style: TextStyle(color: AppColors.muted)),
        SizedBox(height: 24),
        _DiscoverPlaceholder(),
      ],
    );
  }
}

class _DiscoverPlaceholder extends StatelessWidget {
  const _DiscoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.explore_outlined, color: AppColors.burgundy, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Empfehlungen erscheinen hier, sobald Profile und Genres gepflegt sind.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
