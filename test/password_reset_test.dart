import 'dart:convert';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_controller.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/members/password_reset_service.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/member_test_support.dart';

class FakeReset implements PasswordResetService {
  bool fail = false;
  int requests = 0, verifies = 0;
  @override
  Future<String> request(String email) async {
    requests++;
    if (fail) throw const MemberFailure('발송 실패');
    return 'test-challenge';
  }

  @override
  Future<void> verify(String email, String challenge, String code) async {
    verifies++;
    if (code != '123456' || fail) throw const MemberFailure('인증 실패');
  }

  @override
  void close() {}
}

class FailingResetStore extends MemoryMemberStore {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('disk full');
    await super.write(value);
  }
}

void main() {
  test(
    'verified reset preserves profile, invalidates old password and saved session',
    () async {
      final store = MemoryMemberStore(), service = FakeReset();
      final r = MemberRepository(
        store: store,
        hasher: TestHasher(),
        passwordReset: service,
      );
      await r.signUp('회원', 'member@example.com', 'old12345', true);
      await r.save(
        r.current!.copyWith(
          common: {'bio': '소개 유지'},
          sports: ['농구'],
          onboarding: 'complete',
          favorites: {'농구'},
        ),
      );
      final profile = r.current!.toJson();
      await r.logout();
      final before = store.value;
      final id = await r.requestPasswordReset(' MEMBER@example.com ');
      await expectLater(
        r.resetPassword('member@example.com', id, '999999', 'new12345'),
        throwsA(isA<MemberFailure>()),
      );
      expect(store.value, before);
      await r.resetPassword('member@example.com', id, '123456', 'new12345');
      final restored = MemberRepository(
        store: store,
        hasher: TestHasher(),
        passwordReset: service,
      );
      await restored.restore();
      expect(restored.current, isNull);
      await expectLater(
        restored.login('member@example.com', 'old12345', true),
        throwsA(isA<MemberFailure>()),
      );
      await restored.login('member@example.com', 'new12345', true);
      expect(restored.current!.toJson(), profile);
    },
  );
  test(
    'unknown/demo accounts and weak passwords do not call verification',
    () async {
      final service = FakeReset();
      final r = MemberRepository(
        store: MemoryMemberStore(),
        hasher: TestHasher(),
        passwordReset: service,
      );
      await expectLater(
        r.requestPasswordReset('unknown@example.com'),
        throwsA(isA<MemberFailure>()),
      );
      await r.useDemo('demo-basketball');
      await expectLater(
        r.requestPasswordReset('basketball@demo.invalid'),
        throwsA(isA<MemberFailure>()),
      );
      expect(service.requests, 0);
      await r.signUp('회원', 'member@example.com', 'old12345', true);
      await expectLater(
        r.resetPassword('member@example.com', 'id', '123456', 'x'),
        throwsA(isA<MemberFailure>()),
      );
      expect(service.verifies, 0);
    },
  );
  test(
    'disk failure after verification preserves old password and profile',
    () async {
      final store = FailingResetStore();
      final r = MemberRepository(
        store: store,
        hasher: TestHasher(),
        passwordReset: FakeReset(),
      );
      await r.signUp('회원', 'member@example.com', 'old12345', true);
      final before = store.value;
      store.fail = true;
      await expectLater(
        r.resetPassword('member@example.com', 'id', '123456', 'new12345'),
        throwsA(isA<MemberFailure>()),
      );
      expect(store.value, before);
      store.fail = false;
      await r.login('member@example.com', 'old12345', true);
    },
  );
  test(
    'HTTP sends no password and requires matching server verification',
    () async {
      final id = 'a' * 64;
      var mismatch = false;
      final service = HttpPasswordResetService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body.containsKey('password'), false);
          if (request.url.path.endsWith('/request')) {
            return http.Response(jsonEncode({'challengeId': id}), 200);
          }
          expect(body['code'], '123456');
          return http.Response(
            jsonEncode({
              'verified': true,
              'email': mismatch ? 'other@example.com' : body['email'],
              'challengeId': id,
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      expect(await service.request('member@example.com'), id);
      await service.verify('member@example.com', id, '123456');
      mismatch = true;
      await expectLater(
        service.verify('member@example.com', id, '123456'),
        throwsA(isA<MemberFailure>()),
      );
    },
  );
  test(
    'missing SMTP, connection errors and malformed success are explicit failures',
    () async {
      for (final client in [
        MockClient(
          (_) async => http.Response('{"error":"MAIL_NOT_CONFIGURED"}', 503),
        ),
        MockClient((_) async => throw http.ClientException('offline')),
        MockClient((_) async => http.Response('{"challengeId":""}', 200)),
      ]) {
        final service = HttpPasswordResetService(client: client);
        addTearDown(service.close);
        await expectLater(
          service.request('member@example.com'),
          throwsA(isA<MemberFailure>()),
        );
      }
    },
  );
  testWidgets(
    'email code and matching password lead to success and fresh login',
    (tester) async {
      final service = FakeReset();
      final app = AppState(
        members: MemberController(
          MemberRepository(
            store: MemoryMemberStore(),
            hasher: TestHasher(),
            passwordReset: service,
          ),
        ),
      );
      await app.members.initialize();
      await app.members.signUp('회원', 'member@example.com', 'old12345', true);
      await app.members.logout();
      final router = await openApp(tester, app, location: '/password-reset');
      await tester.enterText(
        find.byKey(const Key('reset-email')),
        'member@example.com',
      );
      await keyTap(tester, 'reset-request');
      expect(find.byKey(const Key('reset-code')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reset-code')), '999999');
      await tester.enterText(
        find.byKey(const Key('reset-password')),
        'new12345',
      );
      await tester.enterText(
        find.byKey(const Key('reset-confirm')),
        'different',
      );
      await keyTap(tester, 'reset-submit');
      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(service.verifies, 0);
      await tester.enterText(
        find.byKey(const Key('reset-confirm')),
        'new12345',
      );
      await keyTap(tester, 'reset-submit');
      expect(find.text('인증 실패'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reset-code')), '123456');
      await keyTap(tester, 'reset-submit');
      expect(find.text('비밀번호를 변경했어요'), findsOneWidget);
      await keyTap(tester, 'reset-login');
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        await app.members.login('member@example.com', 'new12345', true),
        isTrue,
      );
    },
  );
  testWidgets('mail failure stays on request step without claiming delivery', (
    tester,
  ) async {
    final service = FakeReset()..fail = true;
    final app = AppState(
      members: MemberController(
        MemberRepository(
          store: MemoryMemberStore(),
          hasher: TestHasher(),
          passwordReset: service,
        ),
      ),
    );
    await app.members.initialize();
    await app.members.signUp('회원', 'member@example.com', 'old12345', true);
    await app.members.logout();
    await openApp(tester, app, location: '/password-reset');
    await tester.enterText(
      find.byKey(const Key('reset-email')),
      'member@example.com',
    );
    await keyTap(tester, 'reset-request');
    expect(find.text('발송 실패'), findsOneWidget);
    expect(find.byKey(const Key('reset-code')), findsNothing);
  });
}
