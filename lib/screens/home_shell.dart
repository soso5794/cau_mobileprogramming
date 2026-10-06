import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import 'ai_chat_screen.dart';
import 'analysis_screen.dart';
import 'plan_screen.dart';
import 'sport_select_screen.dart';

/// 로그인 후의 메인 틀.
/// PDF 모든 화면 하단에 있는 동그라미 4개(운동선택 / plan / 운동분석 / AI) = BottomNavigationBar
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  // 탭 순서는 PDF 그림 순서 그대로: 운동선택, plan, 운동분석, AI
  static const _titles = ['선호 운동을 선택하세요', 'Week Plan', '운동 분석', 'AI 운동 도우미'];

  @override
  Widget build(BuildContext context) {
    // [5강] watch: tabIndex가 바뀌면 이 build가 다시 실행된다.
    final app = context.watch<AppState>();
    final index = app.tabIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[index]),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AppState>().logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 4개 이상이면 fixed로 해야 라벨이 다 보임
        currentIndex: index,
        // [5강] 이벤트 핸들러 안에서는 watch가 아니라 read
        onTap: (i) => context.read<AppState>().goToTab(i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_basketball), label: '운동선택'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: '운동분석'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}
