import 'package:flutter/material.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Neuer Beitrag', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const TextField(
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Was liest du gerade? Teile eine Rezension oder Empfehlung...',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Buch verknüpfen'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Beitrag veröffentlichen'),
          ),
        ],
      ),
    );
  }
}
