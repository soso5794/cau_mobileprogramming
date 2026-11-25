import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';

/// 앱 전체에서 유지되는 5개 기본 탭: 홈·커뮤니티·지도·랭킹·내정보.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = ['운동 Assist', '커뮤니티', '지도', '랭킹', '내정보'];
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: '홈',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups_rounded),
      label: '커뮤니티',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map_rounded),
      label: '지도',
    ),
    NavigationDestination(
      icon: Icon(Icons.emoji_events_outlined),
      selectedIcon: Icon(Icons.emoji_events_rounded),
      label: '랭킹',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: '내정보',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final index = navigationShell.currentIndex;
    final isDark = app.themeMode == ThemeMode.dark;
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    final isFeaturePage = [
      '/me/plan',
      '/me/analysis',
      '/me/ai',
      AppRoutes.weatherPage,
    ].contains(currentPath);

    return Scaffold(
      appBar: isFeaturePage
          ? null
          : AppBar(
              title: Text(
                _titles[index],
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              actions: [
                if (index == 0)
                  IconButton(
                    tooltip: '실시간 운동 날씨',
                    onPressed: () => context.go(AppRoutes.weatherPage),
                    icon: const Icon(Icons.cloud_outlined),
                  ),
                if (app.members.profile?.isDemo == true)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('DEMO'),
                  ),
                if (index == 4)
                  IconButton(
                    tooltip: '설정',
                    onPressed: () => context.push(AppRoutes.settings),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                IconButton(
                  tooltip: isDark ? '라이트 모드' : '다크 모드',
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  onPressed: () => context.read<AppState>().toggleTheme(),
                ),
                const SizedBox(width: 5),
              ],
            ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: _destinations,
      ),
    );
  }
}
