import 'package:exercise_assist/community/community_data.dart';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/recruitment/recruitment.dart';
import 'package:exercise_assist/recruitment/recruitment_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/member_test_support.dart';

RecruitmentInput input({int min = 2, int max = 6, RecruitmentLocation? location}) {
  final start = DateTime.now().add(const Duration(days: 2));
  final day = DateTime(start.year, start.month, start.day, 19);
  return RecruitmentInput(
    sport: '농구', start: day, end: day.add(const Duration(hours: 1)),
    place: '학교 코트', minPeople: min, maxPeople: max, intensity: '보통',
    fields: const {'경기 방식': '3대3'}, details: '농구화 필수', allowMerge: true, location: location,
  );
}

void main() {
  test('input validation and JSON round trip', () {
    expect(input(min: 7).validate(), isNotNull);
    final data = input();
    expect(data.validate(), isNull);
    expect(RecruitmentInput.fromJson(data.toJson()).toJson(), data.toJson());
    expect(RecruitmentDraft.manual(data).body, '농구화 필수');
  });
  test('confirmed coordinates round trip; mismatched place and invalid coordinates fail', () {
    const place = RecruitmentLocation(name: '학교 코트', address: '서울', latitude: 37.5, longitude: 126.9);
    final data = input(location: place);
    expect(data.validate(), isNull);
    expect(RecruitmentInput.fromJson(data.toJson()).location!.toJson(), place.toJson());
    expect(input(location: const RecruitmentLocation(name: '다른 코트', latitude: 37.5, longitude: 126.9)).validate(), isNotNull);
    expect(input(location: const RecruitmentLocation(name: '학교 코트', latitude: 999, longitude: 126.9)).validate(), isNotNull);
    expect(input().location, isNull);
  });
  test('legacy preview can still be read without member metadata', () {
    final post = RecruitmentPreview.fromJson(demoRecruitments.first.toJson());
    expect(post.isMemberPost, isFalse);
    expect(post.recruitmentInput, isNull);
    expect(post.sourceLabel, '예시 모집');
  });
  test('member publication preserves admin data and survives reload', () async {
    final store = MemoryMemberStore();
    final repo = MemberRepository(store: store, hasher: TestHasher());
    await repo.useDemo('demo-basketball');
    final data = input(location: const RecruitmentLocation(name: '학교 코트', latitude: 37.5, longitude: 126.9));
    const draft = RecruitmentDraft('새 모집', '농구화 필수', conditions: ['농구화 필수']);
    await repo.publishRecruitment(data, draft, ownerId: 'demo-basketball');
    final post = repo.operations.posts.first;
    expect(post.sourceLabel, '회원 등록');
    expect(post.authorId, 'demo-basketball');
    expect(post.recruitmentInput!.allowMerge, isTrue);
    expect(post.extraConditions, ['농구화 필수']);
    expect(repo.operations.posts.length, demoRecruitments.length + 1);
    await expectLater(repo.saveRecruitment(post), throwsA(isA<MemberFailure>()));
    await expectLater(repo.publishRecruitment(data, draft, ownerId: 'someone-else'), throwsA(isA<MemberFailure>()));
    final restored = MemberRepository(store: store, hasher: TestHasher());
    await restored.restore();
    expect(restored.operations.posts.first.toJson(), post.toJson());
    await restored.useDemo('demo-running');
    expect(restored.operations.posts.first.id, post.id);
  });
  testWidgets('community -> manual draft -> publish', (tester) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    await openApp(tester, app, location: '/community/basketball', size: const Size(450, 950));
    await keyTap(tester, 'recruitment-create');
    expect(find.text('모집글 작성'), findsOneWidget);
    final place = find.byKey(const Key('recruitment-place'));
    await tester.ensureVisible(place);
    await tester.enterText(place, '테스트 코트');
    await keyTap(tester, 'recruitment-manual');
    expect(find.text('모집글 미리보기'), findsOneWidget);
    await keyTap(tester, 'recruitment-publish');
    expect(app.members.operations.posts.first.place, '테스트 코트');
    expect(find.text('농구 커뮤니티'), findsOneWidget);
    expect(find.text('농구 함께하실 분 모집'), findsOneWidget);
  });
}
