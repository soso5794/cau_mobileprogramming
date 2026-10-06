import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import 'analysis_screen.dart' show scoreColor;

/// PDF 5페이지: Week Plan (하단 탭 1번)
/// ① 운동분석 정보를 바탕으로 캘린더(표) 형식으로 운동 적합 요일 표시 (O △ X)
/// ② ①번 정보를 바탕으로 요일별 추천 일정
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  /// 점수 → 기호. 70↑ O(적합), 40↑ △(보통), 그 아래 X(부적합)
  static Widget _mark(int score) {
    final String text;
    final Color color;
    if (score >= 70) {
      text = 'O';
      color = Colors.blue;
    } else if (score >= 40) {
      text = '△';
      color = Colors.blue;
    } else {
      text = 'X';
      color = Colors.red;
    }
    return Center(
      child: Text(text,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // 위치가 하나라도 저장된 운동만 표에 넣는다 (점수를 계산할 위치가 필요하므로)
    final rows = <String, List<int>>{};
    for (final sport in app.selectedSports) {
      final scores = app.weeklyScores(sport);
      if (scores != null) rows[sport] = scores;
    }

    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '운동선택 탭에서 운동을 고르고\n자주 가는 위치를 저장하면 주간 계획이 만들어져요.',
            textAlign: TextAlign.center,
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
    final border = TableBorder.all(color: Colors.black54);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ──────────── ① 운동 × 요일 표 ────────────
          Table(
            border: border,
            columnWidths: const {0: FixedColumnWidth(64)}, // 첫 칸(운동 이름)만 고정 폭
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: [
                  const SizedBox(height: 36),
                  for (final d in AppState.weekdays)
                    Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              for (final entry in rows.entries)
                TableRow(
                  children: [
                    SizedBox(height: 40, child: Center(child: Text(entry.key))),
                    for (final s in entry.value) _mark(s),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${now.year}년 ${now.month}월 ${now.day}일 기준',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 24),

          // ──────────── ② 추천 일정 ────────────
          const Text('추천 일정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Table(
            border: border,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: [
                  for (final d in AppState.weekdays)
                    SizedBox(
                      height: 32,
                      child: Center(
                          child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ),
                ],
              ),
              TableRow(
                children: [
                  for (int day = 0; day < 7; day++)
                    Container(
                      height: 56,
                      alignment: Alignment.center,
                      color: recommend[day] == '휴식'
                          ? Colors.grey.shade100
                          : scoreColor(rows[recommend[day]]![day]).withAlpha(100), // 0~255, 살짝 투명하게
                      child: Text(
                        recommend[day],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('O: 적합   △: 보통   X: 부적합 (운동별 첫 번째 저장 위치 기준)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
