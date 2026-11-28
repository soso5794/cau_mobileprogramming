import 'package:exercise_assist/features/mate_matcher.dart';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matching data contains diverse demo profiles for all supported sports', () {
    final profiles = MemberRepository.demoProfiles;
    expect(profiles.length, greaterThanOrEqualTo(14));
    for (final sport in ['농구', '런닝', '축구']) {
      expect(profiles.where((profile) => profile.sports.contains(sport)).length, greaterThanOrEqualTo(4));
    }
    expect(profiles.map((profile) => profile.id).toSet().length, profiles.length);
  });

  test('match scoring prefers compatible distance, skill, schedule and locality', () {
    final me = MemberProfile(
      id: 'me@example.com',
      email: 'me@example.com',
      nickname: '나',
      onboarding: 'complete',
      sports: const ['농구'],
      common: const {'region': '서울 동작구', 'times': '주말 오전', 'purposes': '연습·성장'},
      answers: const {
        '농구': {'frequency': '주 2회', 'duration': '90분', 'skill': '중급', 'positions': '포인트가드', 'activityType': '5대5'},
      },
      tierExperiencePoints: 300,
    );
    final close = MemberRepository.demoProfiles.firstWhere((profile) => profile.id == 'demo-basketball-gwanak');
    final far = MemberRepository.demoProfiles.firstWhere((profile) => profile.id == 'demo-basketball-incheon');

    final closeScore = MateMatcher.evaluate(me: me, candidate: close, sport: '농구');
    final farScore = MateMatcher.evaluate(me: me, candidate: far, sport: '농구');

    expect(closeScore.score, greaterThan(farScore.score));
    expect(closeScore.reasons, isNotEmpty);
  });

  test('profiles without shared sport or same account cannot be recommended', () {
    final me = MemberRepository.demoProfiles.first;
    final runningOnly = MemberRepository.demoProfiles.firstWhere((profile) => profile.id == 'demo-running');
    expect(MateMatcher.evaluate(me: me, candidate: runningOnly, sport: '농구').score, 0);
    expect(MateMatcher.evaluate(me: me, candidate: me, sport: '농구').score, 0);
  });
}
