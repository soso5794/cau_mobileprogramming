import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../theme/app_theme.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  static const _sampleMatches = [
    _MatchItem('가볍게 3대3 한 게임', '오늘 18:00', '학교 앞 코트', '초보 환영', '4/6명', '농구'),
    _MatchItem('저녁 공원 5km 같이 달려요', '오늘 19:30', '중앙공원', '7분/km · 대화하며', '3/5명', '런닝'),
    _MatchItem('주말 슈팅 연습 메이트', '토요일 14:00', '동네 코트', '연습 위주', '2/4명', '농구'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sports = app.selectedSports;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        const Text('함께 운동할 사람을 찾아보세요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('운동 종목과 원하는 분위기에 맞는 모임을 둘러보세요.', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFEAF3E5), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Icon(Icons.groups_rounded, size: 32, color: Color(0xFF075B3D)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('내 운동 취향으로 매치하기', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF075B3D))),
              Text(sports.isEmpty ? '홈에서 관심 운동을 먼저 선택해 주세요.' : '관심 운동 ${sports.join(' · ')} 기준으로 추천해요.', style: const TextStyle(fontSize: 12, color: Color(0xFF526354))),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Text('내 주변 모집', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          TextButton.icon(onPressed: () => _showCreateInfo(context), icon: const Icon(Icons.add_rounded), label: const Text('모집 만들기')),
        ]),
        for (final item in _sampleMatches) ...[
          const SizedBox(height: 9),
          _MatchCard(item: item),
        ],
        const SizedBox(height: 10),
        Text('위 모집은 화면 구성 확인을 위한 예시 데이터예요.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }

  static void _showCreateInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('모집 만들기'),
        content: const Text('모집 생성 기능은 서버와 모임 데이터베이스가 연결되면 사용할 수 있어요. 현재 화면에는 예시 모집만 표시됩니다.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('확인'))],
      ),
    );
  }
}

class _MatchItem {
  const _MatchItem(this.title, this.time, this.place, this.tag, this.people, this.sport);
  final String title;
  final String time;
  final String place;
  final String tag;
  final String people;
  final String sport;
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.item});
  final _MatchItem item;

  @override
  Widget build(BuildContext context) {
    final color = sportColor(item.sport);
    return SectionCard(
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(15)), child: Icon(sportIcon(item.sport), color: color, size: 30)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFEAF3E5), borderRadius: BorderRadius.circular(20)), child: const Text('모집중', style: TextStyle(fontSize: 10, color: Color(0xFF075B3D), fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 5),
          Text('◷ ${item.time}  ·  ⌖ ${item.place}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 7),
          Wrap(spacing: 6, children: [
            _tag(item.tag),
            _tag(item.people),
            _tag(item.sport),
          ]),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ]),
    );
  }

  Widget _tag(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(fontSize: 10)));
}
