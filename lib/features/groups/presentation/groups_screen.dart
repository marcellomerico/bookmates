import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/booksquad_ui.dart';
import '../../../core/widgets/state_views.dart';
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
    var nameError = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lesekreis gründen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: AppLimits.groupName,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: nameError ? 'Bitte gib einen Namen ein.' : null,
                ),
              ),
              TextField(
                controller: description,
                maxLength: AppLimits.groupDescription,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privater Lesekreis'),
                subtitle: const Text('Nur für Mitglieder sichtbar'),
                value: isPrivate,
                onChanged: (value) => setDialogState(() => isPrivate = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setDialogState(() => nameError = true);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );
    if (created != true || name.text.trim().isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(groupRepositoryProvider)
          .createGroup(
            creatorId: user.id,
            name: name.text,
            description: description.text,
            isPrivate: isPrivate,
          );
      ref.invalidate(groupsProvider(_query));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRateLimit(e)
                ? authErrorMessage(e)
                : 'Lesekreis konnte nicht erstellt werden.',
          ),
        ),
      );
    }
  }

  Future<void> _joinWithCode() async {
    // Controller is not disposed on purpose: disposing right after showDialog
    // returns breaks the closing animation (same as _createGroup).
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mit Code beitreten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Einladungscode'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final groupId = await ref
          .read(groupRepositoryProvider)
          .joinWithCode(code);
      ref.invalidate(groupsProvider(_query));
      if (mounted) context.push('/groups/$groupId');
    } on PostgrestException catch (e) {
      _showJoinError(
        e.code == 'P0002'
            ? 'Ungültiger Einladungscode.'
            : 'Beitritt fehlgeschlagen. Bitte erneut versuchen.',
      );
    } catch (_) {
      _showJoinError('Beitritt fehlgeschlagen. Bitte erneut versuchen.');
    }
  }

  void _showJoinError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(groupsProvider(_query)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lesekreise',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextButton(onPressed: _joinWithCode, child: const Text('Code')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _createGroup,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(76, 38),
                ),
                child: const Text('Neu'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) =>
                setState(() => _query = value.trim().isEmpty ? null : value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Suche nach Lesekreisen',
            ),
          ),
          const SizedBox(height: 16),
          ...groups.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (_, _) => [
              ErrorState(
                message: 'Lesekreise konnten nicht geladen werden.',
                onRetry: () => ref.invalidate(groupsProvider(_query)),
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    EmptyState(
                      icon: Icons.groups_outlined,
                      title: _query == null
                          ? 'Noch keine Lesekreise'
                          : 'Keine Lesekreise gefunden',
                      message: _query == null
                          ? 'Erstelle den ersten Lesekreis oder tritt mit einem Code bei.'
                          : null,
                    ),
                  ]
                : items
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GroupRow(group: group, query: _query),
                        ),
                      )
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
                color: group.isPrivate
                    ? context.palette.ink
                    : context.palette.burgundy,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                group.isPrivate ? Icons.lock_outline : Icons.menu_book_outlined,
                color: context.palette.onBurgundy,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${group.memberCount} Mitglieder${group.isPrivate ? ' • Privat' : ''}',
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isCreator)
              IconButton(
                tooltip: 'Lesekreis löschen',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog.adaptive(
                      title: const Text('Lesekreis löschen?'),
                      content: const Text(
                        'Alle Beiträge in diesem Lesekreis werden entfernt.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Abbrechen'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Löschen'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  try {
                    await ref
                        .read(groupRepositoryProvider)
                        .deleteGroup(group.id);
                    ref.invalidate(groupsProvider(query));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(authErrorMessage(e))),
                    );
                  }
                },
              )
            else
              TinyPill(
                label: group.isMember ? 'Verlassen' : 'Beitreten',
                onTap: () async {
                  if (user == null) return;
                  final repo = ref.read(groupRepositoryProvider);
                  try {
                    if (group.isMember) {
                      await repo.leaveGroup(groupId: group.id, userId: user.id);
                    } else {
                      await repo.joinGroup(groupId: group.id, userId: user.id);
                    }
                    ref.invalidate(groupsProvider(query));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(authErrorMessage(e))),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
