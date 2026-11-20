import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'models/app_state.dart';
import 'members/member_controller.dart';
import 'members/member_repository.dart';
import 'members/member_store.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState(
    members: MemberController(
      MemberRepository(store: PreferencesMemberStore()),
    ),
  );
  await app.members.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => app,
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
  GoRouter? _router;

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [10강] theme(라이트) + darkTheme(다크)를 둘 다 주고, themeMode로 어느 쪽을 쓸지 고른다.
    // themeMode가 AppState에 있으므로 watch → 토글 버튼을 누르면 앱 전체 색이 바뀐다.
    final app = context.watch<AppState>();
    final themeMode = app.themeMode;
    if (!app.members.ready) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('저장된 계정을 불러오지 못했어요. 기존 데이터는 보존되어 있어요.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: app.members.busy ? null : app.members.initialize,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    _router ??= createAppRouter(app, initialLocation: widget.initialLocation);

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
