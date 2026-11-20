import 'package:exercise_assist/screens/login_screen.dart';
import 'package:exercise_assist/screens/profile_screen.dart';
import 'package:exercise_assist/screens/ai_chat_screen.dart';
import 'package:exercise_assist/screens/location_screen.dart';
import 'package:exercise_assist/screens/route_error_screen.dart';
import 'package:exercise_assist/members/profile_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/member_test_support.dart';

void main() {
  testWidgets('explicit demo login, five tabs and AI input retention', (
    tester,
  ) async {
    final app = makeApp();
    final router = await openApp(tester, app);
    await demoLogin(tester);
    expect(router.routeInformationProvider.value.uri.path, '/sports');
    for (final item in {
      '매치': '/match',
      '지도': '/map',
      '랭킹': '/ranking',
      '내정보': '/me',
    }.entries) {
      await tap(tester, find.widgetWithText(NavigationDestination, item.key));
      expect(router.routeInformationProvider.value.uri.path, item.value);
    }
    expect(find.byType(ProfileScreen), findsOneWidget);
    router.go('/me/ai');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '러닝 준비운동');
    await tap(tester, find.widgetWithText(NavigationDestination, '홈'));
    await tap(tester, find.byTooltip('다크 모드'));
    await tap(tester, find.widgetWithText(NavigationDestination, '내정보'));
    expect(find.text('러닝 준비운동'), findsOneWidget);
    expect(app.themeMode, ThemeMode.dark);
  });
  testWidgets(
    'signup creates pending account then deferred setup preserves destination',
    (tester) async {
      final app = makeApp();
      final router = await openApp(tester, app, location: '/me/settings');
      await tap(tester, find.text('회원가입'));
      await signup(tester);
      expect(find.byType(ProfileEditorScreen), findsOneWidget);
      expect(app.members.profile!.onboarding, 'pending');
      await tap(tester, find.text('나중에'));
      expect(router.routeInformationProvider.value.uri.path, '/me/settings');
      expect(app.members.profile!.onboarding, 'deferred');
    },
  );
  testWidgets('signup cancel preserves login field', (tester) async {
    await openApp(tester, makeApp());
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'keep@example.com',
    );
    await tap(tester, find.text('회원가입'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('keep@example.com'), findsOneWidget);
  });
  testWidgets('protected sport location link resumes through demo login', (
    tester,
  ) async {
    final router = await openApp(
      tester,
      makeApp(),
      location: '/sports/running/locations',
    );
    await demoLogin(tester);
    expect(find.byType(LocationScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sports');
  });
  testWidgets('logout removes protected routes and late AI replies', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    final router = await openApp(tester, app, location: '/me/ai');
    await tester.enterText(find.byType(TextField), '스트레칭');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await app.logout();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsOneWidget);
    router.go('/me/settings');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AiChatScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final path in ['/missing', '/sports/unknown/locations']) {
    testWidgets('bad route $path recovers', (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      final router = await openApp(tester, app, location: path);
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      await tap(tester, find.text('운동 선택으로'));
      expect(router.routeInformationProvider.value.uri.path, '/sports');
    });
  }
  testWidgets('external login return is ignored', (tester) async {
    final router = await openApp(
      tester,
      makeApp(),
      location: '/login?from=https%3A%2F%2Fevil.invalid',
    );
    await demoLogin(tester);
    expect(router.routeInformationProvider.value.uri.path, '/sports');
  });
}
