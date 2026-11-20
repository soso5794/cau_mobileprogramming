import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  static const _rows = [
    ('민트러너', '이번 주 5회', '1'),
    ('코트러너', '이번 주 4회', '2'),
    ('농구곰', '이번 주 3회', '3'),
    ('오늘도운동', '이번 주 2회', '4'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        const Text('운동 랭킹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('꾸준히 운동하는 사람들과 동기부여를 나눠요.', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 17),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFEAF3E5), borderRadius: BorderRadius.circular(18)),
          child: const Column(children: [
            Icon(Icons.emoji_events_rounded, color: Color(0xFFBD8A18), size: 48),
            SizedBox(height: 8),
            Text('이번 주 운동왕', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF075B3D))),
            Text('운동 기록을 쌓고 랭킹에 도전해 보세요.', style: TextStyle(fontSize: 12, color: Color(0xFF526354))),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('주간 TOP 4', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                CircleAvatar(backgroundColor: row.$3 == '1' ? const Color(0xFFFFE8A3) : scheme.surfaceContainerHighest, child: Text(row.$3, style: const TextStyle(fontWeight: FontWeight.w900))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.$1, style: const TextStyle(fontWeight: FontWeight.w800)), Text(row.$2, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))])),
                const Icon(Icons.local_fire_department_outlined, color: Color(0xFFE58A33)),
              ]),
            ),
          ),
        const SizedBox(height: 6),
        Text('현재 랭킹은 화면 예시 데이터이며 실제 사용자 기록과 연결되어 있지 않아요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
