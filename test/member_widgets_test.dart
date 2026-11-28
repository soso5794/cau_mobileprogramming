import 'package:exercise_assist/members/profile_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/member_test_support.dart';

void main() {
  testWidgets('signup validates passwords and acknowledgement', (tester) async {
    await openApp(tester, makeApp(), location: '/signup');
    await keyTap(tester, 'signup-submit');
    expect(find.text('프로토타입 이용 안내를 확인해주세요.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('signup-name')), '테스터');
    await tester.enterText(
      find.byKey(const Key('signup-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'test1234',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm')),
      'different',
    );
    await keyTap(tester, 'signup-agreement');
    await keyTap(tester, 'signup-submit');
    expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
  });
  testWidgets(
    'unregistered login gives inline error instead of creating demo',
    (tester) async {
      final app = makeApp();
      await openApp(tester, app);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'nobody@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'test1234',
      );
      await keyTap(tester, 'login-submit');
      expect(find.text('이메일 또는 비밀번호를 확인해주세요.'), findsOneWidget);
      expect(app.loginId, isNull);
    },
  );
  testWidgets(
    'signup through running questionnaire finishes and updates my page',
    (tester) async {
      final app = makeApp();
      final router = await openApp(tester, app, location: '/signup');
      await signup(tester);
      expect(find.byType(ProfileEditorScreen), findsOneWidget);
      await tester.enterText(find.byKey(const Key('common-age')), '23');
      await tester.enterText(find.byKey(const Key('common-height')), '172');
      await keyTap(tester, 'profile-next');
      await keyTap(tester, '함께할 운동:런닝');
      await tester.enterText(find.byKey(const Key('common-region')), '서울 동작구');
      await keyTap(tester, '선호 시간대:평일 저녁');
      await keyTap(tester, '커뮤니티 이용 목적:친목·취미');
      await keyTap(tester, 'profile-next');
      expect(find.text('런닝 프로필'), findsOneWidget);
      expect(app.members.profile!.sports, isEmpty);
      await keyTap(tester, '일주일 운동 횟수:주 2회');
      await keyTap(tester, '1회 운동 시간:40분');
      await tester.enterText(find.byKey(const Key('런닝-pace')), '6:30');
      await keyTap(tester, '주로 달리는 거리:5km');
      await keyTap(tester, '사용하는 워치:없음');
      await keyTap(tester, 'profile-next');
      await tester.enterText(find.byKey(const Key('common-bio')), '같이 천천히 달려요');
      await keyTap(tester, 'profile-next');
      expect(router.routeInformationProvider.value.uri.path, '/sports');
      expect(app.members.profile!.onboarding, 'complete');
      expect(app.preferenceOf('런닝')['pace'], '6:30');
      router.go('/me');
      await tester.pumpAndSettle();
      expect(find.text('같이 천천히 달려요'), findsOneWidget);
      await keyTap(tester, 'favorite-런닝');
      expect(app.members.profile!.favorites, {'런닝'});
    },
  );
  testWidgets('editing can discard a draft without mutating saved nickname', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    final router = await openApp(tester, app, location: '/me');
    await keyTap(tester, 'edit-profile');
    await tester.enterText(find.byKey(const Key('profile-nickname')), '아직저장안함');
    await tap(tester, find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('변경사항을 버릴까요?'), findsOneWidget);
    await tap(tester, find.text('변경 버리기'));
    expect(router.routeInformationProvider.value.uri.path, '/me');
    expect(app.userName, '코트메이트');
  });
  testWidgets(
    'notifications save locally and master off preserves child choices',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/me/settings/notifications');
      await keyTap(tester, 'notification-team');
      expect(app.members.profile!.notifications['team'], isTrue);
      await keyTap(tester, 'notification-master');
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('notification-team')))
            .onChanged,
        isNull,
      );
      await keyTap(tester, 'notifications-save');
      expect(app.members.profile!.notifications['enabled'], isFalse);
      expect(app.members.profile!.notifications['team'], isFalse);
    },
  );
  testWidgets('demo application cancellation changes only waiting request', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-soccer');
    await openApp(tester, app, location: '/me/applications');
    await keyTap(tester, 'cancel-application');
    await tap(tester, find.text('신청 취소'));
    expect(find.text('상태: 취소'), findsOneWidget);
    expect(find.text('상태: 승인'), findsOneWidget);
    expect(app.members.profile!.cancelledApplications, {'pending'});
  });
  testWidgets('new local member starts at Iron with no fabricated XP or teams', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.signUp('새사용자', 'fresh@example.com', 'test1234', true);
    await app.members.save(
      app.members.profile!.copyWith(onboarding: 'deferred', sports: ['농구']),
    );
    final router = await openApp(tester, app, location: '/me');
    await tester.scrollUntilVisible(
      find.textContaining('현재 티어: 아이언'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('현재 티어: 아이언'), findsOneWidget);
    expect(app.members.profile!.tierExperiencePoints, 0);
    expect(find.textContaining('DEMO 티어'), findsNothing);
    router.go('/me/teams');
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 소속된 팀이 없어요.'), findsOneWidget);
  });
  testWidgets(
    'direct notification route confirms discard and returns to settings',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      final router = await openApp(
        tester,
        app,
        location: '/me/settings/notifications',
      );
      await keyTap(tester, 'notification-team');
      await tap(tester, find.byType(BackButton));
      expect(find.text('변경사항을 버릴까요?'), findsOneWidget);
      await tap(tester, find.text('계속 수정'));
      expect(
        router.routeInformationProvider.value.uri.path,
        '/me/settings/notifications',
      );
      await tap(tester, find.byType(BackButton));
      await tap(tester, find.text('변경 버리기'));
      expect(router.routeInformationProvider.value.uri.path, '/me/settings');
      expect(app.members.profile!.notifications['team'], isTrue);
      await tap(tester, find.text('로그아웃'));
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sport profile saves only on explicit submit', (tester) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    final router = await openApp(
      tester,
      app,
      location: '/sports/basketball/setup',
    );
    await keyTap(tester, '주 포지션:센터');
    expect(app.preferenceOf('농구')['positions'], '슈팅가드');
    await keyTap(tester, 'sport-save');
    expect(app.preferenceOf('농구')['positions'], '센터');
    expect(router.routeInformationProvider.value.uri.path, '/me');
  });
  for (final path in [
    '/login',
    '/signup',
    '/demo',
    '/password-reset',
    '/me',
    '/me/edit',
    '/me/settings',
    '/me/settings/notifications',
    '/me/teams',
    '/me/applications',
    '/sports/basketball/setup',
  ]) {
    testWidgets('small screen 200% dark layout: $path', (tester) async {
      final app = makeApp();
      await app.members.initialize();
      app.toggleTheme();
      if (path.startsWith('/me') || path.startsWith('/sports')) {
        await app.members.useDemo('demo-basketball');
      }
      await openApp(
        tester,
        app,
        location: path,
        size: const Size(360, 740),
        scale: 2,
      );
      // Build the bottom of each form, too.
      final scroll = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable();
      if (scroll.evaluate().isNotEmpty) {
        await tester.drag(scroll.first, const Offset(0, -1000));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
