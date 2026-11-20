import 'dart:convert';

import 'package:exercise_assist/members/member_controller.dart';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/members/profile_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/member_test_support.dart';

class FailingStore extends MemoryMemberStore {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('disk full');
    await super.write(value);
  }
}

void main() {
  test(
    'password hashing salts values and verifies without storing plaintext',
    () async {
      final h = PasswordHasher(iterations: 1000);
      final a = await h.hash('test1234'), b = await h.hash('test1234');
      expect(a['hash'], isNot(b['hash']));
      expect(jsonEncode(a), isNot(contains('test1234')));
      expect(await h.verify('test1234', a), isTrue);
      expect(await h.verify('wrong', a), isFalse);
    },
  );
  test(
    'signup validates duplicates, normalizes email and rejects unknown login',
    () async {
      final r = MemberRepository(
        store: MemoryMemberStore(),
        hasher: TestHasher(),
      );
      await r.signUp('테스터', ' TEST@example.com ', 'test1234', true);
      expect(r.current!.email, 'test@example.com');
      await expectLater(
        r.signUp('두번째', 'test@example.com', 'test1234', true),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.signUp('테스터', 'other@example.com', 'test1234', true),
        throwsA(isA<MemberFailure>()),
      );
      await r.logout();
      await expectLater(
        r.login('unknown@example.com', 'anything', true),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.login('test@example.com', 'wrong', true),
        throwsA(isA<MemberFailure>()),
      );
      expect(r.current, isNull);
    },
  );
  test(
    'profiles favorites notifications and sessions survive reconstruction',
    () async {
      final store = MemoryMemberStore();
      final r = MemberRepository(store: store, hasher: TestHasher());
      await r.signUp('테스터', 'test@example.com', 'test1234', true);
      await r.save(
        r.current!.copyWith(
          sports: ['농구'],
          favorites: {'농구'},
          common: {'bio': '안녕'},
          notifications: {'team': false},
          onboarding: 'complete',
        ),
      );
      final restored = MemberRepository(store: store, hasher: TestHasher());
      await restored.restore();
      expect(restored.current!.favorites, {'농구'});
      expect(restored.current!.common['bio'], '안녕');
      expect(restored.current!.notifications['team'], isFalse);
      await restored.logout();
      final after = MemberRepository(store: store, hasher: TestHasher());
      await after.restore();
      expect(after.current, isNull);
      await after.login('test@example.com', 'test1234', false);
      final noRemember = MemberRepository(store: store, hasher: TestHasher());
      await noRemember.restore();
      expect(noRemember.current, isNull);
    },
  );
  test(
    'separate accounts never inherit profiles and stale save is rejected',
    () async {
      final r = MemberRepository(
        store: MemoryMemberStore(),
        hasher: TestHasher(),
      );
      await r.useDemo('demo-basketball');
      final stale = r.current!;
      await r.logout();
      await r.signUp('빈계정', 'empty@example.com', 'test1234', true);
      expect(r.current!.sports, isEmpty);
      expect(r.current!.favorites, isEmpty);
      expect(r.current!.isDemo, isFalse);
      await expectLater(r.save(stale), throwsA(isA<MemberFailure>()));
    },
  );
  test(
    'failed writes do not mutate current profile or session; retry works',
    () async {
      final store = FailingStore();
      final vm = MemberController(
        MemberRepository(store: store, hasher: TestHasher()),
      );
      addTearDown(vm.dispose);
      await vm.initialize();
      await vm.useDemo('demo-basketball');
      final old = vm.profile!;
      store.fail = true;
      expect(await vm.save(old.copyWith(nickname: '변경이름')), isFalse);
      expect(vm.profile!.nickname, old.nickname);
      expect(await vm.logout(), isFalse);
      expect(vm.profile, isNotNull);
      store.fail = false;
      expect(await vm.logout(), isTrue);
      expect(vm.profile, isNull);
    },
  );
  test(
    'broken local data is preserved and not treated as a clean account',
    () async {
      final store = MemoryMemberStore()..value = 'invalid';
      final vm = MemberController(MemberRepository(store: store));
      addTearDown(vm.dispose);
      expect(await vm.initialize(), isFalse);
      expect(vm.ready, isFalse);
      expect(store.value, 'invalid');
    },
  );
  test('duplicate commands are rejected while a write is in flight', () async {
    final vm = MemberController(
      MemberRepository(store: MemoryMemberStore(), hasher: TestHasher()),
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    final first = vm.signUp('테스터', 'first@example.com', 'test1234', true);
    expect(
      await vm.signUp('다른이름', 'second@example.com', 'test1234', true),
      isFalse,
    );
    expect(await first, isTrue);
    expect(vm.profile!.email, 'first@example.com');
  });
  test(
    'draft is isolated and validates pace and duplicate soccer positions',
    () {
      final p = MemberRepository.demoProfiles.first;
      final d = ProfileDraft(p);
      addTearDown(d.dispose);
      d.setCommon('bio', '다른 소개');
      expect(p.common['bio'], isNot('다른 소개'));
      expect(d.dirty, isTrue);
      expect(
        ProfileDraft.validateSport('런닝', {
          'frequency': '주 2회',
          'duration': '30분',
          'pace': '6:99',
          'distance': '5km',
        }),
        isNotNull,
      );
      expect(
        ProfileDraft.validateSport('축구', {
          'frequency': '주 2회',
          'duration': '60분',
          'skill': '초급',
          'positions': '공격수',
          'subPosition': '공격수',
          'playerBackground': '없음',
          'foot': '오른발',
          'activityType': '축구',
        }),
        isNotNull,
      );
    },
  );
}
