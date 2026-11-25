import 'package:exercise_assist/calendar/workout_event.dart';
import 'package:exercise_assist/community/community_data.dart';
import 'package:exercise_assist/community/recruitment_card.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/screens/home_dashboard_screen.dart';
import 'package:exercise_assist/screens/match_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/member_test_support.dart';

Future<AppState> basketballApp() async {
  final app = makeApp();
  await app.members.initialize();
  await app.members.useDemo('demo-basketball');
  return app;
}

void main() {
  test(
    'recommendation respects interests and favorites without unrelated fallback',
    () {
      expect(recommendedRecruitments([], {}).isEmpty, isTrue);
      expect(recommendedRecruitments(['등산'], {}).isEmpty, isTrue);
      final posts = recommendedRecruitments(['농구', '런닝'], {'런닝'});
      expect(posts.length, 3);
      expect(posts.first.sport, '런닝');
      expect(posts.any((p) => p.sport == '축구'), isFalse);
    },
  );
  test('schedule includes ongoing/future only, sorted and capped at two', () {
    final now = DateTime(2026, 11, 25, 12);
    WorkoutEvent event(String id, int hour, {bool completed = false}) =>
        WorkoutEvent(
          id: id,
          title: id,
          sport: '농구',
          start: now.add(Duration(hours: hour)),
          minutes: 90,
          completed: completed,
        );
    expect(
      upcomingEvents([
        event('later', 3),
        event('past', -3),
        event('done', 1, completed: true),
        event('soon', 1),
        event('ongoing', -1),
      ], now).map((e) => e.id),
      ['ongoing', 'soon'],
    );
  });
  testWidgets(
    'home banner opens saved interests; sport opens filtered community, not survey',
    (tester) async {
      final app = await basketballApp();
      final router = await openApp(tester, app);
      expect(find.byType(HomeDashboardScreen), findsOneWidget);
      expect(find.byKey(const Key('community-sport-농구')), findsNothing);
      await keyTap(tester, 'home-community');
      expect(router.routeInformationProvider.value.uri.path, '/community');
      expect(find.byKey(const Key('community-sport-농구')), findsOneWidget);
      expect(find.byKey(const Key('community-sport-런닝')), findsOneWidget);
      expect(find.byKey(const Key('community-sport-축구')), findsNothing);
      await keyTap(tester, 'community-sport-농구');
      expect(find.byType(MatchScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/community/basketball',
      );
      expect(find.text('가볍게 3대3 한 게임'), findsOneWidget);
      expect(find.text('저녁 공원 5km 같이 달려요'), findsNothing);
      await keyTap(tester, 'recruitment-basketball-3v3');
      expect(find.byType(RecruitmentDetailScreen), findsOneWidget);
      expect(find.text('농구화 · 물 · 개인 수건'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/community/basketball',
      );
    },
  );
  testWidgets(
    'home uses actual saved schedule and recommendation detail returns home',
    (tester) async {
      final app = await basketballApp();
      final event = WorkoutEvent(
        id: 'next',
        title: '내가 저장한 연습',
        sport: '농구',
        start: DateTime.now().add(const Duration(days: 1)),
        minutes: 60,
        place: '학교 코트',
        notes: '농구공 가져오기',
      );
      await app.members.save(app.members.profile!.copyWith(events: [event]));
      final router = await openApp(tester, app);
      await keyTap(tester, 'home-event-next');
      expect(find.text('농구공 가져오기'), findsOneWidget);
      Navigator.of(tester.element(find.text('농구공 가져오기'))).pop();
      await tester.pumpAndSettle();
      await keyTap(tester, 'recruitment-basketball-3v3');
      expect(find.byType(RecruitmentDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sports');
      expect(find.byType(HomeDashboardScreen), findsOneWidget);
    },
  );
  testWidgets('ranking cycles and can pause; old match link opens community', (
    tester,
  ) async {
    final app = await basketballApp();
    final router = await openApp(tester, app);
    expect(find.text('민트러너'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('코트러너'), findsOneWidget);
    await tap(tester, find.byTooltip('랭킹 자동 전환 일시정지'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('코트러너'), findsOneWidget);
    router.go('/match');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
    expect(find.text('나의 운동 커뮤니티'), findsOneWidget);
  });
  testWidgets(
    'interest edits and account switches do not leak previous community cards',
    (tester) async {
      final app = await basketballApp();
      final router = await openApp(tester, app, location: '/community');
      await app.members.save(
        app.members.profile!.copyWith(sports: ['축구'], favorites: {}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community-sport-축구')), findsOneWidget);
      expect(find.byKey(const Key('community-sport-농구')), findsNothing);
      await app.members.logout();
      await tester.pumpAndSettle();
      await app.members.signUp(
        '새계정',
        'fresh-community@example.com',
        'test1234',
        true,
      );
      await app.members.save(
        app.members.profile!.copyWith(onboarding: 'deferred'),
      );
      router.go('/community');
      await tester.pumpAndSettle();
      expect(find.text('아직 선택한 관심 종목이 없어요.'), findsOneWidget);
      expect(find.byKey(const Key('community-sport-축구')), findsNothing);
    },
  );
  for (final path in [
    '/sports',
    '/community',
    '/community/basketball',
    '/community/posts/basketball-3v3',
  ]) {
    for (final width in [320.0, 1100.0]) {
      testWidgets('responsive dark layout $path at $width with large text', (
        tester,
      ) async {
        final app = await basketballApp();
        app.toggleTheme();
        await openApp(
          tester,
          app,
          location: path,
          size: Size(width, 850),
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        final scrollable = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .hitTestable()
            .first;
        for (var i = 0; i < 5; i++) {
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
