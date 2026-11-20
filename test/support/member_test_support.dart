import 'package:exercise_assist/main.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/members/member_controller.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// UI tests replace only expensive cryptography, never production wiring.
class TestHasher extends PasswordHasher {
  @override
  Future<Map<String, Object>> hash(String password) async => {'test': password};
  @override
  Future<bool> verify(String password, Map<String, dynamic> stored) async =>
      stored['test'] == password;
}

AppState makeApp({MemberStore? store}) => AppState(
  members: MemberController(
    MemberRepository(store: store ?? MemoryMemberStore(), hasher: TestHasher()),
  ),
);
Future<GoRouter> openApp(
  WidgetTester tester,
  AppState app, {
  String location = '/',
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  if (!app.members.ready) await app.members.initialize();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: app,
      child: ExerciseAssistApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
      as GoRouter;
}

Future<void> tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> keyTap(WidgetTester tester, String key) =>
    tap(tester, find.byKey(Key(key)));
Future<void> demoLogin(WidgetTester tester) async {
  await tap(tester, find.text('DEMO 계정으로 둘러보기'));
  await keyTap(tester, 'demo-basketball');
}

Future<void> signup(WidgetTester tester) async {
  for (final entry in {
    'signup-name': '새회원',
    'signup-email': 'new@example.com',
    'signup-password': 'test1234',
    'signup-confirm': 'test1234',
  }.entries) {
    await tester.enterText(find.byKey(Key(entry.key)), entry.value);
  }
  await keyTap(tester, 'signup-agreement');
  await keyTap(tester, 'signup-submit');
}
