import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/onboarding/presentation/pages/welcome_page.dart';
import '../../features/roster/presentation/pages/roster_page.dart';
import '../../features/roster/presentation/pages/roster_stats_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);

  return GoRouter(
    initialLocation: hasSeenOnboarding ? '/' : '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const WelcomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DashboardPage(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CalendarPage(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: '/roster',
            name: 'roster',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RosterPage(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: child,
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'stats',
                name: 'roster-stats',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const RosterStatsPage(),
                  transitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _MainShell extends StatelessWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: child,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Neon glow top border
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonCyan.withValues(alpha: 0.0),
                  AppColors.neonCyan.withValues(alpha: 0.5),
                  AppColors.neonMagenta.withValues(alpha: 0.5),
                  AppColors.neonMagenta.withValues(alpha: 0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonCyan.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
          ),
          NavigationBar(
            selectedIndex: _currentIndex(context),
            onDestinationSelected: (index) => _onTap(context, index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Statut',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Calendrier',
              ),
              NavigationDestination(
                icon: Icon(Icons.flight_outlined),
                selectedIcon: Icon(Icons.flight),
                label: 'Roster',
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/calendar')) return 1;
    if (location.startsWith('/roster')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.goNamed('dashboard');
      case 1:
        context.goNamed('calendar');
      case 2:
        context.goNamed('roster');
    }
  }
}
