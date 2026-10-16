import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bookmates_ui.dart';
import '../../../models/group.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String? _query;

  Future<void> _createGroup() async {
    final name = TextEditingController();
    final description = TextEditingController();
    var isPrivate = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neue Gruppe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Private Gruppe'),
                subtitle: const Text('Nur fur Mitglieder sichtbar'),
                value: isPrivate,
                onChanged: (value) => setDialogState(() => isPrivate = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Erstellen')),
          ],
        ),
      ),
    );
    if (created != true || name.text.trim().isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(groupRepositoryProvider).createGroup(
          creatorId: user.id,
          name: name.text,
          description: description.text,
          isPrivate: isPrivate,
        );
    ref.invalidate(groupsProvider(_query));
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(groupsProvider(_query)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Row(
            children: [
              Expanded(child: Text('Gruppen', style: Theme.of(context).textTheme.headlineMedium)),
              ElevatedButton(
                onPressed: _createGroup,
                style: ElevatedButton.styleFrom(minimumSize: const Size(76, 38)),
                child: const Text('Neu'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value.trim().isEmpty ? null : value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Suche nach Lesekreisen',
            ),
          ),
          const SizedBox(height: 16),
          ...groups.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (_, _) => const [Text('Gruppen konnten nicht geladen werden.')],
            data: (items) => items.isEmpty
                ? const [Text('Keine Gruppen gefunden.')]
                : items
                    .map((group) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GroupRow(group: group, query: _query),
                        ))
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({required this.group, required this.query});

  final BookGroup group;
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isCreator = user?.id == group.creatorId;

    return InkWell(
      onTap: () => context.push('/groups/${group.id}'),
      child: SoftCard(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                color: group.isPrivate ? AppColors.ink : AppColors.burgundy,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                group.isPrivate ? Icons.lock_outline : Icons.menu_book_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                    '${group.memberCount} Mitglieder${group.isPrivate ? ' • Privat' : ''}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isCreator)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Gruppe löschen?'),
                      content: const Text('Alle Beiträge in dieser Gruppe werden entfernt.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref.read(groupRepositoryProvider).deleteGroup(group.id);
                  ref.invalidate(groupsProvider(query));
                },
              )
            else
              GestureDetector(
                onTap: () async {
                  if (user == null) return;
                  final repo = ref.read(groupRepositoryProvider);
                  if (group.isMember) {
                    await repo.leaveGroup(groupId: group.id, userId: user.id);
                  } else {
                    await repo.joinGroup(groupId: group.id, userId: user.id);
                  }
                  ref.invalidate(groupsProvider(query));
                },
                child: TinyPill(label: group.isMember ? 'Verlassen' : 'Beitreten'),
              ),
          ],
        ),
      ),
    );
  }
}
