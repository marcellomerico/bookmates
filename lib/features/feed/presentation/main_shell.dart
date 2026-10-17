import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.zero,
          child: NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: widget.navigationShell.goBranch,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            height: 64,
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Feed',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.search),
                label: 'Entdecken',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Neu',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Lesekreise',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
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
