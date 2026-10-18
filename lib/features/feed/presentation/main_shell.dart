import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../groups/presentation/groups_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'create_post_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabTransitionController;
  late Animation<double> _tabFade;
  late Animation<Offset> _tabSlide;

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _configureTabAnimations(direction: 0.015);
    _tabTransitionController.value = 1;
  }

  void _configureTabAnimations({required double direction}) {
    final curved = CurvedAnimation(
      parent: _tabTransitionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _tabFade = Tween<double>(begin: 0.88, end: 1).animate(curved);
    _tabSlide = Tween<Offset>(
      begin: Offset(direction, 0),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIndex = oldWidget.navigationShell.currentIndex;
    final newIndex = widget.navigationShell.currentIndex;
    if (oldIndex != newIndex) {
      final direction = newIndex > oldIndex ? 0.018 : -0.018;
      _configureTabAnimations(direction: direction);
      _tabTransitionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _tabFade,
          child: SlideTransition(
            position: _tabSlide,
            child: widget.navigationShell,
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: widget.navigationShell.currentIndex,
        onSelect: (index) {
          HapticFeedback.selectionClick();
          // Tapping the active tab again returns to its first page.
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

/// Icon-only tab bar (labels for screen readers): outlined when idle, filled
/// when active, a raised "+" in the middle and the user's avatar for Profile.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _TabItem(
                label: 'Feed',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _TabItem(
                label: 'Entdecken',
                icon: Icons.search_rounded,
                activeIcon: Icons.manage_search_rounded,
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              _TabItem(
                label: 'Neuer Beitrag',
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
                child: Container(
                  width: 44,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.burgundy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              _TabItem(
                label: 'Lesekreise',
                icon: Icons.groups_outlined,
                activeIcon: Icons.groups_rounded,
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
              _TabItem(
                label: 'Profil',
                selected: currentIndex == 4,
                onTap: () => onSelect(4),
                child: _ProfileTabIcon(selected: currentIndex == 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.activeIcon,
    this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? activeIcon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            child: SizedBox.expand(
              child: Center(
                child:
                    child ??
                    Icon(
                      selected ? activeIcon : icon,
                      size: 28,
                      color: selected ? AppColors.ink : AppColors.muted,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabIcon extends ConsumerWidget {
  const _ProfileTabIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.ink : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: UserAvatar(
        url: profile?.avatarUrl,
        name: profile?.displayName ?? profile?.username,
        radius: 13,
        semanticLabel: '',
      ),
    );
  }
}

List<StatefulShellBranch> buildMainShellBranches() {
  return [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) => const NoTransitionPage(
            key: ValueKey('home'),
            child: HomeScreen(),
          ),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/discover',
          pageBuilder: (_, state) => NoTransitionPage(
            key: ValueKey('discover'),
            child: DiscoverScreen(initialQuery: state.uri.queryParameters['q']),
          ),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/create',
          pageBuilder: (_, state) => NoTransitionPage(
            key: ValueKey('create'),
            child: CreatePostScreen(
              groupId: state.uri.queryParameters['groupId'],
            ),
          ),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/groups',
          pageBuilder: (_, state) => const NoTransitionPage(
            key: ValueKey('groups'),
            child: GroupsScreen(),
          ),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/profile',
          pageBuilder: (_, state) => const NoTransitionPage(
            key: ValueKey('profile'),
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
  ];
}
