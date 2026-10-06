import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/weather.dart';

/// PDF 4페이지: 운동 분석 화면 (하단 탭 2번)
/// ① 기존에 정해둔 위치 중 선택
/// ② "자동" 클릭 시 기온·습도 등 정보가 자동 입력 (슬라이더로 수동 조작도 가능)
///    + 오늘 날짜 표시
/// ③ 요일별 운동 지수를 색깔로 표시
/// ④ 운동 지수를 바탕으로 LLM이 조언 (지금은 규칙 기반 더미 문장)
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  // 이 화면 안에서만 쓰는 값 → AppState가 아니라 State에 둔다 (5강: 로컬 상태 vs 공유 상태)
  int _selectedDay = DateTime.now().weekday - 1; // 월=0 ... 일=6
  Weather? _edited; // 사용자가 슬라이더로 직접 바꾼 날씨
  String? _editedKey; // 어떤 (위치, 요일)에 대해 바꾼 값인지

  String _key(String location, int day) => '$location|$day';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sport = app.currentSport;
    final location = app.currentLocation;

    // 아직 운동/위치를 고르지 않았으면 안내 화면
    if (sport == null || location == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('운동선택 탭에서 운동과 위치를 먼저 골라주세요.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<AppState>().goToTab(0),
              child: const Text('운동 선택하러 가기'),
            ),
          ],
        ),
      );
    }

    final key = _key(location, _selectedDay);
    final weather = (_editedKey == key && _edited != null)
        ? _edited!
        : app.weatherFor(location, _selectedDay);
    final score = AppState.scoreFor(sport, weather);

    // ③ 요일별 점수 (선택된 요일은 화면에 보이는 날씨 기준)
    final weekScores = List.generate(7, (d) {
      if (d == _selectedDay) return score;
      return AppState.scoreFor(sport, app.weatherFor(location, d));
    });

    void update(Weather w) => setState(() {
          _edited = w;
          _editedKey = key;
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ──────────── ①② 날씨 카드 ────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_drop_down),
                      // ① 저장해둔 위치 중 선택
                      Expanded(
                        child: DropdownButton<String>(
                          value: location,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            for (final loc in app.locationsOf(sport))
                              DropdownMenuItem(value: loc, child: Text('$sport · $loc')),
                          ],
                          onChanged: (loc) {
                            if (loc != null) context.read<AppState>().selectTarget(sport, loc);
                          },
                        ),
                      ),
                      // ② 자동 입력 버튼: 수동으로 바꾼 값을 버리고 (더미)날씨 데이터로 채움
                      OutlinedButton(
                        onPressed: () => setState(() => _edited = null),
                        child: const Text('자동'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _WeatherSlider(
                          icon: Icons.thermostat,
                          label: '기온',
                          unit: '℃',
                          value: weather.temp,
                          min: -10,
                          max: 40,
                          onChanged: (v) => update(weather.copyWith(temp: v)),
                        ),
                      ),
                      Expanded(
                        child: _WeatherSlider(
                          icon: Icons.water_drop_outlined,
                          label: '습도',
                          unit: '%',
                          value: weather.humidity,
                          min: 0,
                          max: 100,
                          onChanged: (v) => update(weather.copyWith(humidity: v)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _WeatherSlider(
                          icon: Icons.air,
                          label: '바람',
                          unit: 'm/s',
                          value: weather.wind,
                          min: 0,
                          max: 20,
                          onChanged: (v) => update(weather.copyWith(wind: v)),
                        ),
                      ),
                      Expanded(
                        child: _WeatherSlider(
                          icon: Icons.umbrella_outlined,
                          label: '시간당 강수',
                          unit: 'mm',
                          value: weather.rain,
                          min: 0,
                          max: 30,
                          onChanged: (v) => update(weather.copyWith(rain: v)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _WeatherSlider(
                          icon: Icons.masks_outlined,
                          label: '미세먼지',
                          unit: '㎍/㎥',
                          value: weather.dust,
                          min: 0,
                          max: 150,
                          onChanged: (v) => update(weather.copyWith(dust: v)),
                        ),
                      ),
                      // 오늘 날짜 표시
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Text(_todayText(),
                              style: const TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ──────────── ③ 요일별 지수 (색깔) ────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int d = 0; d < 7; d++)
                    _DayCircle(
                      label: AppState.weekdays[d],
                      color: scoreColor(weekScores[d]),
                      selected: d == _selectedDay,
                      isToday: d == DateTime.now().weekday - 1,
                      onTap: () => setState(() => _selectedDay = d),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ──────────── 운동지수 + ④ 조언 ────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    // 점수만큼 채워지는 원형 게이지
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 8,
                            color: scoreColor(score, strong: true),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        Text('$score',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$sport지수', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.smart_toy_outlined, size: 18),
                            SizedBox(width: 4),
                            Text('AI 조언', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_advice(sport, score, weather)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _todayText() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.month}월 ${now.day}일  ${two(now.hour)}:${two(now.minute)}';
  }

  /// TODO(팀): LLM API를 연결하면 이 함수 대신 서버/모델 응답을 보여준다.
  String _advice(String sport, int score, Weather w) {
    final tips = <String>[];
    if (w.rain > 1) tips.add('비 소식이 있어요. 미끄럼에 주의하세요.');
    if (w.dust > 80) tips.add('미세먼지가 나빠요. 마스크나 실내 운동을 고려하세요.');
    if (w.temp > 28) tips.add('더운 날씨예요. 수분을 자주 보충하세요.');
    if (w.temp < 5) tips.add('추워요. 준비운동을 충분히 하세요.');
    if (sport != '요트' && w.wind > 10) tips.add('바람이 강해요.');

    final head = score >= 70
        ? '오늘은 $sport 하기 좋은 날이에요!'
        : score >= 40
            ? '$sport 가능하지만 컨디션을 살피며 하세요.'
            : '오늘은 $sport 대신 다른 운동을 추천해요.';
    return [head, ...tips].join('\n');
  }
}

/// 점수 → 색. Plan 화면과 같은 기준을 쓰려고 top-level 함수로 공개.
Color scoreColor(int score, {bool strong = false}) {
  if (score >= 70) return strong ? Colors.blue : Colors.lightBlue.shade200;
  if (score >= 40) return strong ? Colors.orange : Colors.amber.shade200;
  return strong ? Colors.red : Colors.red.shade200;
}

/// 라벨 + 현재 값 + 슬라이더 한 묶음
class _WeatherSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _WeatherSlider({
    required this.icon,
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text('$label ${value.toStringAsFixed(0)}$unit',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 요일 동그라미 (월 화 수 ...)
class _DayCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCircle({
    required this.label,
    required this.color,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 오늘 표시 (PDF의 빨간 체크 ✓)
          Icon(Icons.check, size: 14, color: isToday ? Colors.red : Colors.transparent),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.black87 : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
