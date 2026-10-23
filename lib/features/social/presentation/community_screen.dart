import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../groups/presentation/groups_screen.dart';
import '../../messages/presentation/inbox_screen.dart';
import '../../messages/providers/messages_providers.dart';

/// Reading circles and direct messages in one tab, swiped like on Instagram.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.showMessages = false});

  /// Open on "Nachrichten" (`/groups?tab=messages`, e.g. from `/messages`).
  final bool showMessages;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.showMessages ? 1 : 0,
  );

  @override
  void didUpdateWidget(CommunityScreen old) {
    super.didUpdateWidget(old);
    // The shell keeps this screen alive, so a later link must switch tabs itself.
    if (widget.showMessages && !old.showMessages) _tabs.animateTo(1);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unread = ref.watch(hasUnreadMessagesProvider);
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontSize: 19);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: TabBar(
            controller: _tabs,
            labelStyle: labelStyle,
            unselectedLabelStyle: labelStyle,
            labelColor: p.ink,
            unselectedLabelColor: p.muted,
            indicatorColor: p.burgundy,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: p.line,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            tabs: [
              const Tab(text: 'Lesekreise'),
              Tab(
                child: Semantics(
                  label: unread ? 'Nachrichten, ungelesen' : 'Nachrichten',
                  excludeSemantics: true,
                  child: Badge(
                    isLabelVisible: unread,
                    smallSize: 8,
                    offset: const Offset(10, -2),
                    child: const Text('Nachrichten'),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [GroupsScreen(), InboxList()],
          ),
        ),
      ],
    );
  }
}
