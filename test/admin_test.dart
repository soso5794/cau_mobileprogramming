import 'dart:convert';
import 'package:exercise_assist/admin/admin_gateway.dart';
import 'package:exercise_assist/admin/admin_screen.dart';
import 'package:exercise_assist/admin/operations_data.dart';
import 'package:exercise_assist/calendar/workout_event.dart';
import 'package:exercise_assist/community/community_data.dart';
import 'package:exercise_assist/members/member_controller.dart';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/member_test_support.dart';

class FakeAdmin implements AdminGateway {
  bool valid = true;
  int verifies = 0;
  @override
  Future<String> login(String password) async {
    if (password != 'operator-test') throw const MemberFailure('잘못된 비밀번호');
    valid = true;
    return 'private-operator-token';
  }

  @override
  Future<void> verify(String token) async {
    verifies++;
    if (!valid || token != 'private-operator-token') {
      throw const MemberFailure('인증 만료');
    }
  }

  @override
  Future<void> logout(String token) async {
    valid = false;
  }

  @override
  void close() {}
}

class AdminFailStore extends MemoryMemberStore {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('disk full');
    await super.write(value);
  }
}

MemberRepository repository({MemberStore? store, FakeAdmin? auth}) =>
    MemberRepository(
      store: store ?? MemoryMemberStore(),
      hasher: TestHasher(),
      adminGateway: auth ?? FakeAdmin(),
    );
const entry = RankingEntry(id: 'managed', name: '새랭커', count: 30);
void main() {
  test('normal and demo users cannot invoke any privileged mutation', () async {
    final auth = FakeAdmin();
    final r = repository(auth: auth);
    await r.signUp('일반회원', 'member@example.com', 'test1234', true);
    final p = r.current!;
    for (final login in [() async {}, () => r.useDemo('demo-basketball')]) {
      await login();
      expect(r.isOperator, false);
      expect(r.managedMembers, isEmpty);
      await expectLater(r.saveRanking(entry), throwsA(isA<MemberFailure>()));
      await expectLater(
        r.deleteRanking('seed-1'),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(r.saveManagedProfile(p), throwsA(isA<MemberFailure>()));
      await expectLater(
        r.saveManagedEvent(
          p.id,
          WorkoutEvent(
            id: 'e',
            title: '연습',
            sport: '농구',
            start: DateTime(2026),
            minutes: 60,
          ),
        ),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.deleteManagedEvent(p.id, 'e'),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.saveRecruitment(demoRecruitments.first),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.deleteRecruitment('basketball-3v3'),
        throwsA(isA<MemberFailure>()),
      );
    }
    expect(auth.verifies, 0);
    await expectLater(
      r.signUp('가짜운영자', operatorEmail, 'test1234', true),
      throwsA(isA<MemberFailure>()),
    );
  });
  test(
    'operator changes persist for ordinary members without storing admin token',
    () async {
      final store = MemoryMemberStore(), auth = FakeAdmin();
      final r = repository(store: store, auth: auth);
      await r.signUp('일반회원', 'member@example.com', 'test1234', true);
      final original = r.current!;
      await r.loginOperator('operator-test');
      expect(r.isOperator, true);
      expect(r.current!.isDemo, false);
      await r.saveManagedProfile(
        original.copyWith(
          nickname: '수정회원',
          common: {'bio': '소개 수정'},
          onboarding: 'deferred',
        ),
      );
      final event = WorkoutEvent(
        id: 'admin-event',
        title: '운영자 일정',
        sport: '농구',
        start: DateTime(2026, 12, 1),
        minutes: 60,
      );
      await r.saveManagedEvent(original.id, event);
      // A stale profile edit must not undo the newly managed calendar.
      await r.saveManagedProfile(
        original.copyWith(nickname: '수정회원', onboarding: 'deferred'),
      );
      await r.saveRanking(entry);
      await r.deleteRecruitment('basketball-3v3');
      expect(r.operations.sortedRankings.first.name, '새랭커');
      expect(r.operations.logs.length, 5);
      expect(store.value, isNot(contains('private-operator-token')));
      expect(store.value, isNot(contains('operator-test')));
      final restored = repository(store: store);
      await restored.restore();
      expect(restored.current, isNull);
      expect(restored.isOperator, false);
      await restored.login(original.email, 'test1234', true);
      expect(restored.current!.nickname, '수정회원');
      expect(restored.current!.events.single.id, event.id);
      expect(
        restored.operations.posts.any((p) => p.id == 'basketball-3v3'),
        false,
      );
      expect(restored.operations.sortedRankings.first.name, '새랭커');
      await r.logout();
      expect(r.isOperator, false);
      expect(auth.valid, false);
    },
  );
  test(
    'expired authorization and disk failure never commit changes or audit rows',
    () async {
      final store = AdminFailStore(), auth = FakeAdmin();
      final r = repository(store: store, auth: auth);
      await r.loginOperator('operator-test');
      final before = store.value;
      auth.valid = false;
      await expectLater(r.saveRanking(entry), throwsA(isA<MemberFailure>()));
      expect(store.value, before);
      expect(r.operations.logs, isEmpty);
      auth.valid = true;
      store.fail = true;
      await expectLater(r.saveRanking(entry), throwsStateError);
      expect(store.value, before);
      expect(r.operations.logs, isEmpty);
      expect(r.operations.rankings.length, 4);
    },
  );
  test(
    'old store migrates and forged stored operator session does not grant authority',
    () async {
      final store = MemoryMemberStore();
      final r = repository(store: store);
      await r.signUp('일반회원', 'member@example.com', 'test1234', true);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      data.remove('operations');
      data['profiles'][operatorId] = MemberProfile(
        id: operatorId,
        email: operatorEmail,
        nickname: '가짜운영자',
      ).toJson();
      data['session'] = operatorId;
      store.value = jsonEncode(data);
      final restored = repository(store: store);
      await restored.restore();
      expect(restored.current, isNull);
      expect(restored.isOperator, false);
      expect(restored.operations.rankings.length, 4);
    },
  );
  test(
    'HTTP admin token travels in Authorization and invalid claims fail',
    () async {
      final token = 'a' * 64;
      var invalid = false;
      final gateway = HttpAdminGateway(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({'email': operatorEmail, 'token': token}),
              200,
            );
          }
          expect(r.headers['Authorization'], 'Bearer $token');
          return http.Response(
            jsonEncode({'authorized': !invalid, 'email': operatorEmail}),
            200,
          );
        }),
      );
      addTearDown(gateway.close);
      expect(await gateway.login('operator-test'), token);
      await gateway.verify(token);
      invalid = true;
      await expectLater(gateway.verify(token), throwsA(isA<MemberFailure>()));
    },
  );
  testWidgets(
    'operator sign-in opens management, rank edit updates home and logout removes access',
    (tester) async {
      final app = AppState(members: MemberController(repository()));
      final router = await openApp(tester, app);
      await keyTap(tester, 'open-operator-login');
      await tester.enterText(
        find.byKey(const Key('operator-password')),
        'operator-test',
      );
      await keyTap(tester, 'operator-login');
      expect(
        find.byType(AdminScreen),
        findsOneWidget,
        reason:
            'route=${router.routeInformationProvider.value.uri}, operator=${app.members.isOperator}, error=${app.members.error}',
      );
      await keyTap(tester, 'admin-section-2');
      await keyTap(tester, 'admin-add-ranking');
      await tester.enterText(find.byKey(const Key('rank-name')), '최고랭커');
      await tester.enterText(find.byKey(const Key('rank-count')), '99');
      await keyTap(tester, 'rank-save');
      router.go('/sports');
      await tester.pumpAndSettle();
      expect(find.text('최고랭커'), findsOneWidget);
      await app.members.logout();
      await tester.pumpAndSettle();
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(find.byType(AdminScreen), findsNothing);
    },
  );
  testWidgets('ordinary user direct admin route is blocked', (tester) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    final router = await openApp(tester, app, location: '/admin');
    expect(router.routeInformationProvider.value.uri.path, '/me');
    expect(find.byType(AdminScreen), findsNothing);
    expect(find.text('운영 관리'), findsNothing);
  });
  testWidgets(
    'operator creates member calendar event and small-screen tabs render',
    (tester) async {
      final app = AppState(members: MemberController(repository()));
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await app.members.loginOperator('operator-test');
      await openApp(
        tester,
        app,
        location: '/admin',
        size: const Size(320, 850),
        scale: 2,
      );
      await keyTap(tester, 'admin-section-1');
      await keyTap(tester, 'admin-event-add-demo-basketball');
      await tester.enterText(find.byKey(const Key('event-title')), '운영자 추가 일정');
      await keyTap(tester, 'event-save');
      expect(
        app.members.managedMembers
            .firstWhere((p) => p.id == 'demo-basketball')
            .events
            .single
            .title,
        '운영자 추가 일정',
      );
      expect(tester.takeException(), isNull);
      for (var i = 2; i < 5; i++) {
        await keyTap(tester, 'admin-section-$i');
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('managed survey edits the selected member, not the operator', (
    tester,
  ) async {
    final app = AppState(members: MemberController(repository()));
    await app.members.initialize();
    await app.members.useDemo('demo-running');
    await app.members.loginOperator('operator-test');
    await openApp(tester, app, location: '/admin');
    await keyTap(tester, 'admin-profile-demo-running');
    await tester.enterText(find.byKey(const Key('profile-nickname')), '관리된러너');
    for (var i = 0; i < 4; i++) {
      await keyTap(tester, 'profile-next');
    }
    expect(
      app.members.managedMembers
          .firstWhere((p) => p.id == 'demo-running')
          .nickname,
      '관리된러너',
    );
    expect(app.members.profile!.nickname, '운영자');
    expect(find.byType(AdminScreen), findsOneWidget);
  });
  testWidgets(
    'operator recruitment edits show in community details and empty ranking is safe',
    (tester) async {
      final app = AppState(members: MemberController(repository()));
      await app.members.initialize();
      await app.members.loginOperator('operator-test');
      final router = await openApp(tester, app, location: '/admin');
      await keyTap(tester, 'admin-section-3');
      await keyTap(tester, 'admin-post-basketball-3v3');
      await tester.enterText(find.byKey(const Key('post-title')), '운영자 수정 모집');
      await keyTap(tester, 'post-save');
      router.go('/community/posts/basketball-3v3');
      await tester.pumpAndSettle();
      expect(find.text('운영자 수정 모집'), findsOneWidget);
      expect(find.text('운영자 등록 · 참가 신청 준비 중'), findsOneWidget);
      for (final rank in [...app.members.operations.rankings]) {
        await app.members.deleteRanking(rank.id);
      }
      router.go('/sports');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('아직 등록된 랭킹이 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
