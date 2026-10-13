import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../theme/app_theme.dart';

/// PDF 5페이지: Week Plan (하단 탭 1번)
/// ① 운동분석 정보를 바탕으로 캘린더(표) 형식으로 운동 적합 요일 표시 (O △ X)
/// ② ①번 정보를 바탕으로 요일별 추천 일정
///
/// [꾸미기] 표 칸의 O/△/X를 색 동그라미 배지로, 추천 일정은 운동 색 카드로 표시.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  /// 점수 → 배지. 70↑ O(적합), 40↑ △(보통), 그 아래 X(부적합)
  static Widget _mark(int score) {
    final color = ScoreColors.of(score);
    final String symbol = score >= 70 ? 'O' : (score >= 40 ? '△' : 'X');
    return Center(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(45),
          shape: BoxShape.circle,
        ),
        child: Text(symbol,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // 위치가 하나라도 저장된 운동만 표에 넣는다 (점수를 계산할 위치가 필요하므로)
    final rows = <String, List<int>>{};
    for (final sport in app.selectedSports) {
      final scores = app.weeklyScores(sport);
      if (scores != null) rows[sport] = scores;
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_outlined, size: 80, color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text('아직 주간 계획이 없어요',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '운동선택 탭에서 운동을 고르고\n자주 가는 위치를 저장하면 주간 계획이 만들어져요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // ② 요일마다 점수가 가장 높은 운동을 추천 (40점 미만이면 휴식)
    final recommend = List.generate(7, (day) {
      String best = '휴식';
      int bestScore = 39;
      rows.forEach((sport, scores) {
        if (scores[day] > bestScore) {
          best = sport;
          bestScore = scores[day];
        }
      });
      return best;
    });

    final now = DateTime.now();
    final today = now.weekday - 1;
    final lineColor = scheme.outlineVariant.withAlpha(120);

    // 요일 머리글 한 칸 (오늘은 파란 알약으로 강조)
    Widget dayHeader(int d) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: d == today ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppState.weekdays[d],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: d == today
                    ? scheme.onPrimary
                    : (d >= 5 ? ScoreColors.bad : null), // 토·일은 빨간 글씨
              ),
            ),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ──────────── ① 운동 × 요일 표 ────────────
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(icon: Icons.grid_view_rounded, text: '요일별 운동 적합도'),
                const SizedBox(height: 12),
                Table(
                  // 가로줄만 연하게 → 깔끔한 표
                  border: TableBorder(horizontalInside: BorderSide(color: lineColor)),
                  columnWidths: const {0: FixedColumnWidth(70)}, // 첫 칸(운동 이름)만 고정 폭
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        const SizedBox(height: 36),
                        for (int d = 0; d < 7; d++) dayHeader(d),
                      ],
                    ),
                    for (final entry in rows.entries)
                      TableRow(
                        children: [
                          SizedBox(
                            height: 46,
                            child: Row(
                              children: [
                                Icon(sportIcon(entry.key),
                                    size: 16, color: sportColor(entry.key)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(entry.key,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          for (final s in entry.value) _mark(s),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${now.year}년 ${now.month}월 ${now.day}일 기준 · 운동별 첫 번째 저장 위치',
                    textAlign: TextAlign.right,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ──────────── ② 추천 일정 ────────────
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(icon: Icons.auto_awesome_rounded, text: '추천 일정'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (int day = 0; day < 7; day++)
                      Expanded(
                        child: _RecommendCell(
                          day: AppState.weekdays[day],
                          sport: recommend[day],
                          isToday: day == today,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 범례
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            children: [
              for (final s in [80, 50, 10])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _mark(s),
                    const SizedBox(width: 4),
                    Text(s >= 70 ? '적합' : (s >= 40 ? '보통' : '부적합'),
                        style: text.bodySmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 추천 일정 한 칸: 요일 + 운동 아이콘 + 운동 이름 (운동 색 배경)
class _RecommendCell extends StatelessWidget {
  final String day;
  final String sport; // '휴식'일 수도 있음
  final bool isToday;

  const _RecommendCell({required this.day, required this.sport, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rest = sport == '휴식';
    final color = rest ? scheme.outline : sportColor(sport);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(rest ? 20 : 35),
        borderRadius: BorderRadius.circular(14),
        border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Icon(rest ? Icons.hotel_rounded : sportIcon(sport), size: 22, color: color),
          const SizedBox(height: 4),
          FittedBox(
            // 칸이 좁으면 글자를 자동으로 줄여서 넘치지 않게
            fit: BoxFit.scaleDown,
            child: Text(sport,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
