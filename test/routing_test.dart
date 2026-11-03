import 'package:exercise_assist/main.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/screens/ai_chat_screen.dart';
import 'package:exercise_assist/screens/analysis_screen.dart';
import 'package:exercise_assist/screens/location_screen.dart';
import 'package:exercise_assist/screens/login_screen.dart';
import 'package:exercise_assist/screens/plan_screen.dart';
import 'package:exercise_assist/screens/route_error_screen.dart';
import 'package:exercise_assist/screens/signup_screen.dart';
import 'package:exercise_assist/screens/sport_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

Future<GoRouter> openApp(
  WidgetTester tester,
  AppState state, {
  String location = '/',
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: ExerciseAssistApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await tester.binding.setSurfaceSize(null);
  });
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
      as GoRouter;
}

Future<void> login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'routing-demo');
  await tester.enterText(find.byType(TextField).at(1), 'demo');
  final button = find.widgetWithText(FilledButton, '로그인');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> signup(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  for (final entry in ['테스터', '22', 'new-user', 'demo'].indexed) {
    await tester.enterText(fields.at(entry.$1), entry.$2);
  }
  final button = find.widgetWithText(FilledButton, '가입하기');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'login, route-driven tabs, theme change and chat draft retention',
    (tester) async {
      final app = AppState();
      final router = await openApp(tester, app);
      expect(find.byType(LoginScreen), findsOneWidget);
      await login(tester);
      expect(router.routeInformationProvider.value.uri.path, '/sports');
      expect(router.canPop(), isFalse);
      await tab(tester, 'Plan');
      expect(find.byType(PlanScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/plan');
      await tab(tester, '운동분석');
      expect(find.byType(AnalysisScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/analysis');
      await tester.tap(find.text('운동 선택하러 가기'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sports');
      await tab(tester, 'AI');
      await tester.enterText(find.byType(TextField), '러닝 준비운동');
      await tab(tester, 'Plan');
      await tab(tester, 'AI');
      expect(find.text('러닝 준비운동'), findsOneWidget);
      await tester.tap(find.byTooltip('다크 모드'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/ai');
      expect(find.text('러닝 준비운동'), findsOneWidget);
      expect(app.themeMode, ThemeMode.dark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signup returns ID and preserves the protected destination', (
    tester,
  ) async {
    final app = AppState();
    final router = await openApp(tester, app, location: '/plan');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/plan',
    );
    await tester.tap(find.text('새로가입'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);
    await signup(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'new-user',
    );
    await tester.enterText(find.byType(TextField).at(1), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/plan');
    expect(router.canPop(), isFalse);
  });

  testWidgets('cancel signup uses back and keeps login input', (tester) async {
    await openApp(tester, AppState());
    await tester.enterText(find.byType(TextField).first, 'keep-me');
    await tester.tap(find.text('새로가입'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('keep-me'), findsOneWidget);
  });

  testWidgets('direct signup link can complete without a previous page', (
    tester,
  ) async {
    final app = AppState();
    final router = await openApp(tester, app, location: '/signup?from=%2Fai');
    await signup(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/ai',
    );
    expect(app.login('new-user', 'demo'), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(AiChatScreen), findsOneWidget);
  });

  testWidgets(
    'location parameter, system back and selection route to analysis',
    (tester) async {
      final app = AppState()..login('demo', 'demo');
      app.setSelectedSports(['농구']);
      final router = await openApp(tester, app, location: '/sports');
      await tester.tap(find.text('농구'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/sports/basketball/locations',
      );
      expect(
        tester.widget<LocationScreen>(find.byType(LocationScreen)).sport,
        '농구',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SportSelectScreen), findsOneWidget);
      expect(app.currentLocation, isNull);
      await tester.tap(find.text('농구'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '흑석동 코트');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.text('흑석동 코트'));
      await tester.pumpAndSettle();
      expect(app.currentSport, '농구');
      expect(app.currentLocation, '흑석동 코트');
      expect(find.byType(AnalysisScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/analysis');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'protected detail deep link survives login and has a parent to return to',
    (tester) async {
      final router = await openApp(
        tester,
        AppState(),
        location: '/sports/running/locations',
      );
      await login(tester);
      expect(
        tester.widget<LocationScreen>(find.byType(LocationScreen)).sport,
        '런닝',
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/sports/running/locations',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sports');
    },
  );

  testWidgets(
    'logout while AI reply is pending blocks protected route replay',
    (tester) async {
      final app = AppState()..login('demo', 'demo');
      final router = await openApp(tester, app, location: '/ai');
      await tester.enterText(find.byType(TextField), '스트레칭');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(app.loginId, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      // 브라우저 뒤로 가기/플랫폼 링크가 보호 주소를 다시 전달한 상황.
      await router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: Uri.parse('/ai')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AiChatScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('platform URL changes select the corresponding tab', (
    tester,
  ) async {
    final router = await openApp(
      tester,
      AppState()..login('demo', 'demo'),
      location: '/sports',
    );
    await router.routeInformationProvider.didPushRouteInformation(
      RouteInformation(uri: Uri.parse('/plan')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlanScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  for (final path in ['/missing-screen', '/sports/unknown/locations']) {
    testWidgets('invalid route $path has a recovery action', (tester) async {
      final router = await openApp(
        tester,
        AppState()..login('demo', 'demo'),
        location: path,
      );
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      await tester.tap(find.text('운동 선택으로'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sports');
      expect(find.byType(SportSelectScreen), findsOneWidget);
    });
  }

  testWidgets('external login return URL is ignored', (tester) async {
    final router = await openApp(
      tester,
      AppState(),
      location: '/login?from=https%3A%2F%2Fexample.com',
    );
    await login(tester);
    expect(router.routeInformationProvider.value.uri.path, '/sports');
  });
}
