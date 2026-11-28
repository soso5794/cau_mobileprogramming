import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../calendar/workout_event.dart';
import '../members/member_models.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';

class PlannedWorkout {
  const PlannedWorkout({required this.event, required this.score, required this.reason});
  final WorkoutEvent event;
  final int score;
  final String reason;
}

/// Explainable profile-based planner. It uses the member's declared frequency,
/// duration, preferred time, saved calendar and the app's weekly suitability data.
class AiWorkoutPlanner {
  static List<PlannedWorkout> generate({
    required MemberProfile profile,
    required DateTime now,
    required Map<String, List<int>?> weeklyScores,
  }) {
    final existing = [...profile.events];
    final planned = <PlannedWorkout>[];
    final usedDays = <String>{};
    final preferred = profile.common['times'] ?? '';
    final place = (profile.common['place'] ?? profile.common['region'] ?? '').trim();

    for (final sport in profile.sports) {
      final answers = profile.answers[sport] ?? const <String, String>{};
      final target = _frequency(answers['frequency']);
      final duration = _duration(answers['duration']);
      final scores = weeklyScores[sport];
      final selectedDaysForSport = <int>[];

      for (var session = 0; session < target; session++) {
        PlannedWorkout? best;
        var bestDayOffset = -1;
        for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
          if (!_dayAllowed(now.add(Duration(days: dayOffset)), preferred)) continue;
          final day = DateTime(now.year, now.month, now.day + dayOffset);
          final start = DateTime(day.year, day.month, day.day, _preferredHour(preferred, day));
          if (!start.isAfter(now.add(const Duration(minutes: 15)))) continue;
          if (selectedDaysForSport.any((value) => (value - dayOffset).abs() <= 1)) continue;
          final dayKey = '${day.year}-${day.month}-${day.day}';
          if (usedDays.contains(dayKey)) continue;

          final suitability = scores == null || scores.length < 7 ? 65 : scores[day.weekday - 1];
          final spreadBonus = selectedDaysForSport.isEmpty ? 0 : 8;
          final dayPreference = _dayPreference(day, preferred);
          final score = (suitability + spreadBonus + dayPreference).clamp(0, 100).toInt();
          final event = WorkoutEvent(
            id: 'ai-${now.microsecondsSinceEpoch}-$sport-$dayOffset-$session',
            title: '$sport 맞춤 훈련',
            sport: sport,
            start: start,
            minutes: duration,
            place: place,
            notes: 'AI 주간 계획 · 주 ${target}회 목표 · 운동 적합도 ${suitability}점',
          );
          if (existing.any(event.overlaps)) continue;

          if (best == null || score > best.score) {
            best = PlannedWorkout(
              event: event,
              score: score,
              reason: scores == null
                  ? '선호 시간대와 기존 일정 사이에 배치했어요.'
                  : '운동 적합도 ${suitability}점과 휴식 간격을 고려했어요.',
            );
            bestDayOffset = dayOffset;
          }
        }

        // When a busy calendar leaves too few spaced days, try any free day once.
        if (best == null) {
          for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
            if (!_dayAllowed(now.add(Duration(days: dayOffset)), preferred)) continue;
            final day = DateTime(now.year, now.month, now.day + dayOffset);
            final start = DateTime(day.year, day.month, day.day, _preferredHour(preferred, day));
            if (!start.isAfter(now.add(const Duration(minutes: 15)))) continue;
            final dayKey = '${day.year}-${day.month}-${day.day}';
            if (usedDays.contains(dayKey)) continue;
            final event = WorkoutEvent(
              id: 'ai-${now.microsecondsSinceEpoch}-$sport-$dayOffset-$session',
              title: '$sport 맞춤 훈련',
              sport: sport,
              start: start,
              minutes: duration,
              place: place,
              notes: 'AI 주간 계획 · 주 ${target}회 목표',
            );
            if (existing.any(event.overlaps)) continue;
            final suitability = scores == null || scores.length < 7 ? 65 : scores[day.weekday - 1];
            best = PlannedWorkout(
              event: event,
              score: suitability,
              reason: '기존 일정과 겹치지 않는 시간으로 배치했어요.',
            );
            bestDayOffset = dayOffset;
            break;
          }
        }

        if (best == null) break;
        planned.add(best);
        existing.add(best.event);
        selectedDaysForSport.add(bestDayOffset);
        usedDays.add('${best.event.start.year}-${best.event.start.month}-${best.event.start.day}');
      }
    }

    planned.sort((a, b) => a.event.start.compareTo(b.event.start));
    return List.unmodifiable(planned);
  }

  static int _frequency(String? value) {
    final match = RegExp(r'\d+').firstMatch(value ?? '');
    if (match == null) return 2;
    return int.parse(match.group(0)!).clamp(1, 4).toInt();
  }

  static int _duration(String? value) {
    final match = RegExp(r'\d+').firstMatch(value ?? '');
    if (match == null) return 45;
    return int.parse(match.group(0)!).clamp(20, 180).toInt();
  }

  static int _preferredHour(String value, DateTime day) {
    final preferences = value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final isWeekend = day.weekday >= DateTime.saturday;
    final dayLabel = isWeekend ? '주말' : '평일';
    final matching = preferences.where((entry) => entry.contains(dayLabel)).toList();
    final selected = matching.isNotEmpty
        ? matching.first
        : (preferences.isEmpty ? '' : preferences.first);
    if (selected.contains('오전') || selected.contains('새벽')) return 9;
    if (selected.contains('오후') && !selected.contains('저녁')) return 15;
    if (selected.contains('저녁')) return 19;
    return 18;
  }

  static bool _dayAllowed(DateTime date, String preference) {
    final weekday = date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
    if (preference.contains('평일') && !preference.contains('주말')) return weekday;
    if (preference.contains('주말') && !preference.contains('평일')) return !weekday;
    return true;
  }

  static int _dayPreference(DateTime date, String preference) {
    final weekday = date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
    if (preference.contains('평일') && weekday) return 8;
    if (preference.contains('주말') && !weekday) return 8;
    return 0;
  }
}

class AiWorkoutPlannerCard extends StatefulWidget {
  const AiWorkoutPlannerCard({super.key});

  @override
  State<AiWorkoutPlannerCard> createState() => _AiWorkoutPlannerCardState();
}

class _AiWorkoutPlannerCardState extends State<AiWorkoutPlannerCard> {
  List<PlannedWorkout> _preview = const [];
  bool _saving = false;
  String? _message;

  void _generate(AppState app) {
    final profile = app.members.profile;
    if (profile == null) return;
    final scores = <String, List<int>?>{
      for (final sport in profile.sports) sport: app.weeklyScores(sport),
    };
    setState(() {
      _preview = AiWorkoutPlanner.generate(
        profile: profile,
        now: DateTime.now(),
        weeklyScores: scores,
      );
      _message = _preview.isEmpty
          ? '이번 주에는 빈 시간대를 찾지 못했어요. 캘린더 일정을 확인하거나 선호 시간대를 바꿔주세요.'
          : '프로필의 주간 운동 횟수·운동 시간·선호 시간·기존 일정에 맞춰 ${_preview.length}개의 계획을 만들었어요.';
    });
  }

  Future<void> _save(AppState app) async {
    final profile = app.members.profile;
    if (profile == null || _preview.isEmpty || _saving) return;
    setState(() => _saving = true);
    var saved = 0;
    for (final plan in _preview) {
      final current = app.members.profile;
      if (current == null || current.id != profile.id) break;
      if (current.events.any((event) => event.overlaps(plan.event))) continue;
      final ok = await app.members.saveEvent(plan.event, ownerId: profile.id);
      if (ok) {
        saved++;
      } else {
        break;
      }
    }
    if (!mounted) return;
    final error = app.members.error;
    setState(() {
      _saving = false;
      _message = saved > 0
          ? '$saved개의 운동 계획을 내 캘린더에 저장했어요.'
          : error ?? '일정을 저장하지 못했어요.';
      if (saved > 0) _preview = const [];
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message!)));
  }

  String _dateLabel(DateTime date) =>
      '${date.month}.${date.day} (${const ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1]})';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.members.profile;
    final scheme = Theme.of(context).colorScheme;
    if (profile == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('AI 맞춤형 운동 플래너', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                Chip(label: const Text('프로필 기반'), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '내 운동 빈도와 운동 시간, 선호 시간대, 저장된 일정을 분석해 다음 7일 계획을 추천해요.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _generate(app),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('AI 주간 계획 생성'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final plan in _preview)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withAlpha(110), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: sportColor(plan.event.sport).withAlpha(35),
                        child: Icon(sportIcon(plan.event.sport), size: 18, color: sportColor(plan.event.sport)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_dateLabel(plan.event.start)} · ${plan.event.start.hour.toString().padLeft(2, '0')}:00 · ${plan.event.sport}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${plan.event.minutes}분 · ${plan.reason}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('${plan.score}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(app),
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.calendar_month_rounded),
                label: Text(_saving ? '캘린더 저장 중...' : '추천 일정을 캘린더에 저장'),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '추천 점수는 운동 적합도와 일정 여유를 이용한 앱 내부 규칙 기반 점수예요. 의료·훈련 처방이 아니며, 저장 전 일정을 확인해주세요.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
