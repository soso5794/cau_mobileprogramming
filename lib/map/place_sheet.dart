import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../routing/app_routes.dart';
import '../weather/weather_forecast.dart';
import '../weather/weather_service.dart';
import 'sport_place.dart';

/// 점수 → 등급 라벨/색. 지도 마커 카드와 시트에서 같이 쓴다.
({String label, Color color}) conditionGrade(int score) {
  if (score >= 70) return (label: '좋음', color: const Color(0xFF16824A));
  if (score >= 40) return (label: '보통', color: const Color(0xFFE0A100));
  return (label: '주의', color: const Color(0xFFD64545));
}

/// 마커를 누르면 아래에서 올라오는 장소 상세 시트.
///
/// [6강 async] FutureBuilder로 날씨 HTTP 요청(기존 WeatherService)을 기다리고,
/// 받은 시간별 예보에 기존 ExerciseConditions 규칙을 적용해 종목별 지수를 보여준다.
class PlaceSheet extends StatefulWidget {
  const PlaceSheet({
    super.key,
    required this.place,
    required this.service,
    this.sport,
    this.distanceKm,
  });

  final SportPlace place;
  final WeatherService service;
  final String? sport; // 지도에서 선택한 필터 종목 (없으면 장소의 모든 종목)
  final double? distanceKm;

  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<PlaceSheet> {
  late Future<WeatherForecast> _forecast = _load();

  Future<WeatherForecast> _load() =>
      widget.service.fetch(widget.place.toWeatherPlace());

  void _retry() => setState(() => _forecast = _load());

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final scheme = Theme.of(context).colorScheme;
    final app = context.watch<AppState>();
    final sports = widget.sport == null ? place.sports : [widget.sport!];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              place.name,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              [
                place.area,
                place.kind,
                if (widget.distanceKm != null)
                  '내 위치에서 ${formatDistance(widget.distanceKm!)}',
              ].join(' · '),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (place.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(place.note, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 14),

            // ── 내 운동 장소로 저장 (종목별 토글) ──
            const Text('내 운동 장소로 저장',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final sport in place.sports)
                  FilterChip(
                    key: ValueKey('save-${place.id}-$sport'),
                    avatar: Icon(sportIcon(sport), size: 18, color: sportColor(sport)),
                    label: Text(sport),
                    selected: app.locationsOf(sport).contains(place.name),
                    onSelected: (on) {
                      if (on) {
                        app.addLocation(sport, place.name);
                      } else {
                        app.removeLocation(sport, place.name);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // ── 실시간 날씨 + 종목별 운동 지수 ──
            FutureBuilder<WeatherForecast>(
              future: _forecast,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('이 장소의 날씨를 불러오는 중…'),
                      SizedBox(height: 8),
                      LinearProgressIndicator(),
                    ],
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  final error = snap.error;
                  return Row(children: [
                    Expanded(
                      child: Text(
                        error is WeatherFailure ? error.message : '날씨를 불러오지 못했어요.',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                    TextButton(onPressed: _retry, child: const Text('다시 시도')),
                  ]);
                }
                return _WeatherSummary(forecast: snap.data!, sports: sports);
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.match);
                },
                icon: const Icon(Icons.groups_outlined),
                label: const Text('이 근처 매치 보러 가기'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '지수는 수업용 규칙 기반 점수예요. 코트 예약·점유 상태는 표시하지 않아요.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherSummary extends StatelessWidget {
  const _WeatherSummary({required this.forecast, required this.sports});
  final WeatherForecast forecast;
  final List<String> sports;

  @override
  Widget build(BuildContext context) {
    final now = forecast.hours.first;
    final next12 = forecast.hours.take(12).toList();
    final scheme = Theme.of(context).colorScheme;

    Widget stat(IconData icon, String value, String label) => Expanded(
          child: Column(children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지금 날씨 · ${koreanWeatherTime(now.time)} 기준',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          stat(Icons.thermostat, '${now.temperature.toStringAsFixed(1)}°C', '기온'),
          stat(Icons.umbrella_outlined,
              '${(now.rainProbability ?? 0).round()}%', '강수확률'),
          stat(Icons.air, '${now.wind.toStringAsFixed(1)}m/s', '바람'),
          stat(Icons.water_drop_outlined, '${now.humidity.round()}%', '습도'),
        ]),
        const SizedBox(height: 14),
        for (final sport in sports) ...[
          _SportScoreRow(sport: sport, now: now, hours: next12),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SportScoreRow extends StatelessWidget {
  const _SportScoreRow({required this.sport, required this.now, required this.hours});
  final String sport;
  final WeatherSample now;
  final List<WeatherSample> hours;

  @override
  Widget build(BuildContext context) {
    final score = ExerciseConditions.evaluate(sport, now).score;
    final grade = conditionGrade(score);
    // 앞으로 12시간 중 지수가 가장 높은 시간 (동점이면 더 이른 시간)
    var best = hours.first;
    var bestScore = ExerciseConditions.evaluate(sport, best).score;
    for (final hour in hours.skip(1)) {
      final s = ExerciseConditions.evaluate(sport, hour).score;
      if (s > bestScore) {
        best = hour;
        bestScore = s;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(sportIcon(sport), color: sportColor(sport), size: 20),
          const SizedBox(width: 6),
          Text(sport, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('$score점 · ${grade.label}',
              style: TextStyle(fontWeight: FontWeight.w900, color: grade.color)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            color: grade.color,
            backgroundColor: grade.color.withAlpha(40),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '12시간 내 추천: ${koreanWeatherTime(best.time)} ($bestScore점)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
