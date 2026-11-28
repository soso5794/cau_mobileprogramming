import 'package:exercise_assist/community/community_data.dart';
import 'package:exercise_assist/community/recruitment_card.dart';
import 'package:exercise_assist/map/recruitment_pins.dart';
import 'package:exercise_assist/recruitment/recruitment.dart';
import 'package:exercise_assist/recruitment/recruitment_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_test.dart' show FixtureWeatherService;
import 'support/member_test_support.dart';

RecruitmentInput _input({
  String sport = '농구',
  String place = '테스트 코트',
  RecruitmentLocation? location,
  DateTime? day,
}) {
  final base = day ?? DateTime.now().add(const Duration(days: 2));
  final start = DateTime(base.year, base.month, base.day, 19);
  return RecruitmentInput(
    sport: sport, start: start, end: start.add(const Duration(hours: 1)),
    place: place, minPeople: 2, maxPeople: 6, intensity: '보통',
    fields: const {'경기 방식': '3대3'}, details: '', allowMerge: true,
    location: location,
  );
}

RecruitmentPreview _post(String id, RecruitmentInput input) => RecruitmentPreview(
      id: id, sport: input.sport, title: '$id 모집', time: input.schedule,
      place: input.place, condition: '보통', people: '모집 2~6명',
      description: '', equipment: '', isDemo: false, authorId: 'u',
      recruitmentInput: input,
    );

void main() {
  const court = RecruitmentLocation(name: '테스트 코트', latitude: 37.53, longitude: 126.98);

  test('같은 좌표의 모집글은 한 핀으로 묶이고, 좌표 없는 글은 제외된다', () {
    final posts = [
      _post('a', _input(location: court)),
      _post('b', _input(location: court)),
      _post('c', _input(place: '어딘가 동네 코트')), // 좌표 없음
    ];
    final pins = recruitmentPins(posts);
    expect(pins, hasLength(1));
    expect(pins.single.posts.map((p) => p.id), ['a', 'b']);
    expect(pins.single.mainSport, '농구');
    expect(unmappedRecruitmentCount(posts), 1);
  });

  test('장소명이 지도 운동 장소와 같으면 그 좌표를 쓴다 (예: 보라매공원)', () {
    final pins = recruitmentPins([_post('a', _input(sport: '축구', place: '보라매공원'))]);
    expect(pins.single.latitude, 37.4925);
    expect(pins.single.longitude, 126.9200);
  });

  test('종목 필터와 지난 모집 제외', () {
    final now = DateTime.now();
    final posts = [
      _post('basket', _input(location: court)),
      _post('run', _input(sport: '런닝', place: '노들섬')),
    ];
    expect(recruitmentPins(posts, sport: '런닝').single.posts.single.id, 'run');
    // 3일 뒤 기준으로 보면 2일 뒤 모집은 이미 끝난 글
    expect(recruitmentPins(posts, now: now.add(const Duration(days: 3))), isEmpty);
  });

  test('예시(데모) 모집글은 좌표가 없어 지도에 뜨지 않는다', () {
    expect(recruitmentPins(demoRecruitments), isEmpty);
  });

  testWidgets('회원이 지도에서 찍은 장소로 모집글을 쓰면 지도에 핀이 뜨고 상세로 이동한다',
      (tester) async {
    final app = makeApp(weatherService: FixtureWeatherService());
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    final ok = await app.members.publishRecruitment(
      _input(location: court),
      const RecruitmentDraft('저녁 3대3 하실 분', '농구화 필수'),
      ownerId: 'demo-basketball',
    );
    expect(ok, isTrue);
    final post = app.members.operations.posts.first;

    await openApp(tester, app, location: '/map');
    final pin = find.byKey(const ValueKey('post-pin-37.5300,126.9800'));
    expect(pin, findsOneWidget);
    expect(find.text('모집 1'), findsOneWidget);

    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(find.text('저녁 3대3 하실 분'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('map-post-${post.id}')));
    await tester.pumpAndSettle();
    // 기존 모집글 상세 화면(/community/posts/:id)이 열렸는지 화면으로 확인
    expect(find.byType(RecruitmentDetailScreen), findsOneWidget);
  });

  testWidgets('모집글 칩을 끄면 핀이 사라진다', (tester) async {
    final app = makeApp(weatherService: FixtureWeatherService());
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    await app.members.publishRecruitment(
      _input(location: court),
      const RecruitmentDraft('저녁 3대3 하실 분', '농구화 필수'),
      ownerId: 'demo-basketball',
    );
    await openApp(tester, app, location: '/map');
    expect(find.byKey(const ValueKey('post-pin-37.5300,126.9800')), findsOneWidget);
    // 칩 줄은 가로 스크롤이라 화면 밖에 있을 수 있음 → 먼저 보이게 스크롤
    final toggle = find.byKey(const ValueKey('map-posts-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post-pin-37.5300,126.9800')), findsNothing);
    expect(find.byKey(const ValueKey('marker-cau')), findsOneWidget); // 운동 장소는 유지
  });
}
