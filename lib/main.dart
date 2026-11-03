import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'models/app_state.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    // [5강] 앱 맨 위에 ChangeNotifierProvider를 한 번 감싸 두면
    // 아래 모든 화면에서 context.watch / context.read 로 AppState를 꺼내 쓸 수 있다.
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ExerciseAssistApp(),
    ),
  );
}

class ExerciseAssistApp extends StatefulWidget {
  const ExerciseAssistApp({super.key, this.initialLocation});
  final String? initialLocation;

  @override
  State<ExerciseAssistApp> createState() => _ExerciseAssistAppState();
}

class _ExerciseAssistAppState extends State<ExerciseAssistApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(
      context.read<AppState>(),
      initialLocation: widget.initialLocation,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [10강] theme(라이트) + darkTheme(다크)를 둘 다 주고, themeMode로 어느 쪽을 쓸지 고른다.
    // themeMode가 AppState에 있으므로 watch → 토글 버튼을 누르면 앱 전체 색이 바뀐다.
    final themeMode = context.watch<AppState>().themeMode;

    return MaterialApp.router(
      title: '운동 Assist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
