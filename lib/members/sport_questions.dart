import 'package:flutter/material.dart';

import 'member_widgets.dart';

class SportQuestions extends StatelessWidget {
  const SportQuestions({
    super.key,
    required this.sport,
    required this.answers,
    required this.onChanged,
  });
  final String sport;
  final Map<String, String> answers;
  final void Function(String, String) onChanged;
  Widget choice(String label, String key, List<String> options) => ChoiceGroup(
    label: label,
    options: options,
    selected: {answers[key] ?? ''},
    onSelected: (v) => onChanged(key, v),
  );
  Widget field(String label, String key, {String? hint}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: TextFormField(
      key: ValueKey('$sport-$key'),
      initialValue: answers[key] ?? '',
      decoration: memberInput(label, hint: hint),
      onChanged: (v) => onChanged(key, v),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      choice('일주일 운동 횟수', 'frequency', [
        '주 1회',
        '주 2회',
        '주 3회',
        '주 4회 이상',
        '불규칙',
      ]),
      choice('1회 운동 시간', 'duration', [
        '30분',
        '40분',
        '60분',
        '90분',
        '120분',
        '180분 이상',
      ]),
      if (sport == '농구' || sport == '축구') ...[
        choice('현재 실력 · 자가 평가', 'skill', ['입문', '초급', '중급', '상급']),
        choice('선수 경험 · 자기 신고', 'playerBackground', [
          '없음',
          '학교 운동부',
          '실업·프로',
          '응답 안 함',
        ]),
        const Text('선수 경험과 실력은 자기 신고이며 인증된 티어와 구분돼요.'),
        if (answers['playerBackground'] == '학교 운동부' ||
            answers['playerBackground'] == '실업·프로')
          field('선수 활동 기간·경력 (선택)', 'career', hint: '예: 고교 운동부 3년'),
      ],
      if (sport == '농구') ...[
        choice('주 포지션', 'positions', [
          '포인트가드',
          '슈팅가드',
          '스몰포워드',
          '파워포워드',
          '센터',
          '미정',
        ]),
        field('국적 (선택)', 'nationality', hint: '응답하지 않아도 괜찮아요'),
        choice('주로 하는 경기', 'activityType', ['3대3', '5대5', '슈팅 연습']),
      ],
      if (sport == '런닝') ...[
        field('평균 페이스 · 분:초/km', 'pace', hint: '예: 6:30 / 아직 모르면 모름'),
        choice('주로 달리는 거리', 'distance', ['3km 이하', '5km', '10km', '하프', '풀']),
        choice('사용하는 워치', 'watch', [
          '없음',
          'Apple Watch',
          'Galaxy Watch',
          'Garmin',
          '기타',
        ]),
        const Text('워치 종류만 저장하며 건강 데이터나 기기 연결 권한을 요청하지 않아요.'),
      ],
      if (sport == '축구') ...[
        choice('주발', 'foot', ['오른발', '왼발', '양발']),
        choice('주로 하는 형태', 'activityType', ['축구', '풋살', '둘 다']),
        choice('주 포지션', 'positions', ['공격수', '미드필더', '수비수', '골키퍼', '미정']),
        choice('부포지션 (선택)', 'subPosition', ['없음', '공격수', '미드필더', '수비수', '골키퍼']),
      ],
      if (!['농구', '런닝', '축구'].contains(sport))
        choice('현재 실력 · 자가 평가', 'skill', ['입문', '초급', '중급', '상급']),
    ],
  );
}
