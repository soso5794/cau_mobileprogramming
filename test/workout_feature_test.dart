import 'package:exercise_assist/calendar/workout_event.dart';
import 'package:exercise_assist/features/ai_workout_planner.dart';
import 'package:exercise_assist/features/workout_tier.dart';
import 'package:exercise_assist/features/workout_qr_session.dart';
import 'package:exercise_assist/members/member_controller.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/ranking/ranking_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/member_test_support.dart';

void main() {
  test('QR payload round-trips and expired QR codes are rejected', () {
    final now = DateTime(2026, 11, 28, 18);
    final session = WorkoutQrSession(
      id: 'match-test-001',
      sport: '농구',
      teamName: '캠퍼스 볼',
      opponentName: '코트 러너',
      place: '중앙대 코트',
      hostId: 'host@example.com',
      matchAt: now,
      issuedAt: now,
      teamScore: 21,
      opponentScore: 18,
    );

    final decoded = WorkoutQrSession.fromQrPayload(
      session.toQrPayload(),
      now: now,
    );
    expect(decoded.id, session.id);
    expect(decoded.sport, '농구');
    expect(decoded.teamScore, 21);
    expect(decoded.isHostedBy('host@example.com'), isTrue);
    expect(decoded.hostId, isNot('host@example.com'));

    expect(
      () => WorkoutQrSession.fromQrPayload(
        session.toQrPayload(),
        now: now.add(const Duration(hours: 49)),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('QR issue records host attendance and awards personal tier XP without changing ranking', () async {
    final vm = MemberController(
      MemberRepository(store: MemoryMemberStore(), hasher: TestHasher()),
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    await vm.useDemo('demo-basketball');
    final now = DateTime.now();
    final initialXp = vm.profile!.tierExperiencePoints;
    final originalRankings = vm.operations.sportRankings;
    final session = WorkoutQrSession(
      id: 'match-host-result-001',
      sport: '농구',
      teamName: '코트메이트 팀',
      opponentName: '상대 팀',
      place: '학교 야외 코트',
      hostId: vm.profile!.id,
      matchAt: now,
      issuedAt: now,
      teamScore: 21,
      opponentScore: 17,
      attendeeIds: [vm.profile!.id],
    );

    expect(await vm.createWorkoutQrSession(session), isTrue);
    expect(vm.profile!.verifiedSessionIds, contains(session.id));
    expect(vm.profile!.events.single.completed, isTrue);
    expect(vm.profile!.tierExperiencePoints, initialXp + WorkoutTier.xpForSession(session));
    expect(vm.operations.sportRankings.map((entry) => entry.toJson()).toList(), originalRankings.map((entry) => entry.toJson()).toList(), reason: 'QR 인증은 공개 팀 랭킹을 바꾸지 않아요.');
    expect(vm.operations.workoutSessions.single.attendeeIds, [vm.profile!.id]);
  });

  test('QR scan confirms a participant once, awards tier XP and leaves public ranking unchanged', () async {
    final store = MemoryMemberStore();
    final vm = MemberController(
      MemberRepository(store: store, hasher: TestHasher()),
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    await vm.useDemo('demo-basketball');
    final now = DateTime.now();
    final hostId = vm.profile!.id;
    final originalRankings = vm.operations.sportRankings;
    final session = WorkoutQrSession(
      id: 'match-checkin-001',
      sport: '축구',
      teamName: '중앙 FC',
      opponentName: '상대 FC',
      place: '풋살장',
      hostId: hostId,
      matchAt: now,
      issuedAt: now,
      teamScore: 3,
      opponentScore: 2,
    );
    expect(await vm.createWorkoutQrSession(session), isTrue);
    final qr = WorkoutQrSession.fromQrPayload(session.toQrPayload());

    await vm.useDemo('demo-running');
    final guestId = vm.profile!.id;
    final guestXp = vm.profile!.tierExperiencePoints;
    expect(WorkoutTier.forXp(guestXp).name, '아이언');
    expect(await vm.confirmWorkoutQrSession(qr), isTrue);
    expect(vm.profile!.verifiedSessionIds, contains(session.id));
    expect(vm.profile!.events.single.completed, isTrue);
    expect(vm.operations.workoutSessions.single.attendeeIds, contains(vm.profile!.id));
    expect(vm.profile!.tierExperiencePoints, guestXp + WorkoutTier.xpForSession(session));
    expect(WorkoutTier.forXp(vm.profile!.tierExperiencePoints).name, '브론즈');
    expect(vm.operations.sportRankings.map((entry) => entry.toJson()).toList(), originalRankings.map((entry) => entry.toJson()).toList(), reason: 'QR 인증으로 공개 팀 랭킹을 바꾸지 않아요.');

    final xpAfterFirstConfirm = vm.profile!.tierExperiencePoints;
    expect(await vm.confirmWorkoutQrSession(qr), isFalse);
    expect(vm.error, contains('이미 인증'));
    expect(vm.profile!.tierExperiencePoints, xpAfterFirstConfirm, reason: '중복 QR 인증으로 경험치를 추가 지급하지 않아요.');
  });

  test('QR running session awards both participants personal XP without adding public running ranks', () async {
    final vm = MemberController(
      MemberRepository(store: MemoryMemberStore(), hasher: TestHasher()),
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    await vm.useDemo('demo-running');
    final now = DateTime.now();
    final hostId = vm.profile!.id;
    final hostInitialXp = vm.profile!.tierExperiencePoints;
    final initialRankings = vm.operations.sportRankings;
    final session = WorkoutQrSession(
      id: 'match-running-001',
      sport: '런닝',
      teamName: '러닝 크루',
      opponentName: '러닝 기록',
      place: '석촌호수',
      hostId: hostId,
      matchAt: now,
      issuedAt: now,
      distance: RunningDistance.five,
      seconds: 1500,
    );
    expect(await vm.createWorkoutQrSession(session), isTrue);
    final qr = WorkoutQrSession.fromQrPayload(session.toQrPayload());

    final hostXp = vm.profile!.tierExperiencePoints;
    expect(hostXp, hostInitialXp + WorkoutTier.xpForSession(session));
    expect(WorkoutTier.forXp(hostXp).name, '브론즈');
    await vm.useDemo('demo-basketball');
    final guestId = vm.profile!.id;
    final guestXp = vm.profile!.tierExperiencePoints;
    expect(await vm.confirmWorkoutQrSession(qr), isTrue);
    expect(vm.profile!.tierExperiencePoints, guestXp + WorkoutTier.xpForSession(session));
    expect(vm.operations.sportRankings.map((entry) => entry.toJson()).toList(), initialRankings.map((entry) => entry.toJson()).toList());
    expect(vm.operations.workoutSessions.single.attendeeIds, containsAll([hostId, guestId]));
  });


  test('tier ladder follows the supplied ten-stage progression', () {
    expect(WorkoutTier.all.map((tier) => tier.name).toList(), [
      '아이언', '브론즈', '실버', '골드', '플래티넘',
      '에메랄드', '다이아몬드', '마스터', '그랜드마스터', '챌린저',
    ]);
    expect(WorkoutTier.forXp(0).name, '아이언');
    expect(WorkoutTier.forXp(100).name, '브론즈');
    expect(WorkoutTier.forXp(3200).name, '챌린저');
    expect(WorkoutTier.xpToNext(99), 1);
    expect(WorkoutTier.nextForXp(3200), isNull);
  });

  test('AI planner respects weekly frequency and does not overlap existing events', () {
    final profile = MemberRepository.demoProfiles.first;
    final now = DateTime(2026, 11, 28, 10);
    final existing = profile.copyWith(
      events: [
        WorkoutEventForTest.event(DateTime(2026, 11, 30, 19)),
      ],
    );
    final plans = AiWorkoutPlanner.generate(
      profile: existing,
      now: now,
      weeklyScores: {
        '농구': List.filled(7, 80),
        '런닝': List.filled(7, 75),
      },
    );

    expect(plans, isNotEmpty);
    expect(plans.length, lessThanOrEqualTo(4));
    for (final plan in plans) {
      expect(existing.events.any(plan.event.overlaps), isFalse);
    }
  });
}

abstract final class WorkoutEventForTest {
  static event(DateTime start) =>
      WorkoutEvent(
        id: 'already-booked',
        title: '기존 운동 일정',
        sport: '농구',
        start: start,
        minutes: 90,
        place: '학교 코트',
      );
}
