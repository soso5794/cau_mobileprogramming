import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import 'ai_chat_screen.dart';
import 'analysis_screen.dart';
import 'plan_screen.dart';
import 'sport_select_screen.dart';

/// 로그인 후의 메인 틀.
/// PDF 모든 화면 하단에 있는 동그라미 4개(운동선택 / plan / 운동분석 / AI)
///
/// [꾸미기] BottomNavigationBar → Material 3의 NavigationBar로 교체.
/// 선택된 탭 아이콘 뒤에 알약 모양 배경(indicator)이 생기고, 선택 시 채워진 아이콘으로 바뀐다.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  // 탭 순서는 PDF 그림 순서 그대로: 운동선택, plan, 운동분석, AI
  static const _titles = ['운동 선택', 'Week Plan', '운동 분석', 'AI 운동 도우미'];

  @override
  Widget build(BuildContext context) {
    // [5강] watch: tabIndex/테마가 바뀌면 이 build가 다시 실행된다.
    final app = context.watch<AppState>();
    final index = app.tabIndex;
    final isDark = app.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent, // 배경색과 자연스럽게 이어지도록
        scrolledUnderElevation: 0,
        actions: [
          // [10강] 다크모드 토글: 버튼 하나로 앱 전체 테마 전환
          IconButton(
            tooltip: isDark ? '라이트 모드' : '다크 모드',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => context.read<AppState>().toggleTheme(),
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              context.read<AppState>().logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      // [4강] IndexedStack: 탭을 바꿔도 각 탭 화면의 상태(스크롤, 입력 중인 글 등)가 유지된다.
      body: IndexedStack(
        index: index,
        children: const [
          SportSelectScreen(),
          PlanScreen(),
          AnalysisScreen(),
          AiChatScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        // [5강] 이벤트 핸들러 안에서는 watch가 아니라 read
        onDestinationSelected: (i) => context.read<AppState>().goToTab(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_basketball_outlined),
            selectedIcon: Icon(Icons.sports_basketball),
            label: '운동선택',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '운동분석',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
