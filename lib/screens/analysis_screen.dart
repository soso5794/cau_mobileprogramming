import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';
import '../models/sport_icons.dart';
import '../models/weather.dart';
import '../theme/app_theme.dart';

/// PDF 4페이지: 운동 분석 화면 (하단 탭 2번)
/// ① 기존에 정해둔 위치 중 선택
/// ② "자동" 클릭 시 기온·습도 등 정보가 자동 입력 (슬라이더로 수동 조작도 가능)
///    + 오늘 날짜 표시
/// ③ 요일별 운동 지수를 색깔로 표시
/// ④ 운동 지수를 바탕으로 LLM이 조언 (지금은 규칙 기반 더미 문장)
///
/// [꾸미기] 날씨 항목마다 고유 색 슬라이더, 요일 원은 AnimatedContainer,
///          점수 게이지는 TweenAnimationBuilder로 0 → 점수까지 차오르는 애니메이션.
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // 아직 운동/위치를 고르지 않았으면 안내 화면
    if (sport == null || location == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, size: 80, color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text('운동과 위치를 먼저 골라주세요',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('운동선택 탭에서 운동을 누르고 위치를 등록하면\n여기에 날씨 분석이 나타나요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.sports),
                icon: const Icon(Icons.sports_basketball_outlined),
                label: const Text('운동 선택하러 가기'),
              ),
            ],
          ),
        ),
      );
    }

    final key = _key(location, _selectedDay);
    final weather = (_editedKey == key && _edited != null)
        ? _edited!
        : app.weatherFor(location, _selectedDay);
    final score = AppState.scoreFor(sport, weather);
    final color = sportColor(sport);

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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ──────────── ①② 날씨 카드 ────────────
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    // ① 저장해둔 위치 중 선택 (운동 색 알약 모양)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: DropdownButton<String>(
                          value: location,
                          isExpanded: true,
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(16),
                          icon: Icon(Icons.expand_more_rounded, color: color),
                          items: [
                            for (final loc in app.locationsOf(sport))
                              DropdownMenuItem(
                                value: loc,
                                child: Row(
                                  children: [
                                    Icon(sportIcon(sport), size: 18, color: color),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text('$sport · $loc',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (loc) {
                            if (loc != null) context.read<AppState>().selectTarget(sport, loc);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ② 자동 입력 버튼: 수동으로 바꾼 값을 버리고 (더미)날씨 데이터로 채움
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _edited = null),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: const Text('자동'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WeatherSlider(
                        icon: Icons.thermostat_rounded,
                        color: const Color(0xFFEF4444),
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
                        icon: Icons.water_drop_rounded,
                        color: const Color(0xFF0EA5E9),
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
                        icon: Icons.air_rounded,
                        color: const Color(0xFF14B8A6),
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
                        icon: Icons.umbrella_rounded,
                        color: const Color(0xFF6366F1),
                        label: '강수',
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _WeatherSlider(
                        icon: Icons.masks_rounded,
                        color: const Color(0xFF94A3B8),
                        label: '미세먼지',
                        unit: '',
                        value: weather.dust,
                        min: 0,
                        max: 150,
                        onChanged: (v) => update(weather.copyWith(dust: v)),
                      ),
                    ),
                    // 오늘 날짜 표시
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14, right: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(_todayText(),
                                  textAlign: TextAlign.end,
                                  style: text.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ──────────── ③ 요일별 지수 (색깔) ────────────
          SectionCard(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: SectionTitle(icon: Icons.date_range_rounded, text: '이번 주 운동 지수'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int d = 0; d < 7; d++)
                      _DayCircle(
                        label: AppState.weekdays[d],
                        color: ScoreColors.of(weekScores[d]),
                        selected: d == _selectedDay,
                        isToday: d == DateTime.now().weekday - 1,
                        onTap: () => setState(() => _selectedDay = d),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // 색 범례
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(color: ScoreColors.good, text: '좋음'),
                    SizedBox(width: 12),
                    _Legend(color: ScoreColors.normal, text: '보통'),
                    SizedBox(width: 12),
                    _Legend(color: ScoreColors.bad, text: '나쁨'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ──────────── 운동지수 + ④ 조언 ────────────
          SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScoreGauge(score: score, sport: sport),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withAlpha(120),
                      borderRadius: const BorderRadius.only(
                        // 말풍선처럼 왼쪽 위 모서리만 덜 둥글게
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
                            const SizedBox(width: 4),
                            Text('AI 조언',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: scheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_advice(sport, score, weather),
                            style: const TextStyle(height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    if (w.rain > 1) tips.add('☔ 비 소식이 있어요. 미끄럼에 주의하세요.');
    if (w.dust > 80) tips.add('😷 미세먼지가 나빠요. 실내 운동도 고려하세요.');
    if (w.temp > 28) tips.add('🥵 더운 날씨예요. 수분을 자주 보충하세요.');
    if (w.temp < 5) tips.add('🥶 추워요. 준비운동을 충분히 하세요.');
    if (sport != '요트' && w.wind > 10) tips.add('💨 바람이 강해요.');

    final head = score >= 70
        ? '오늘은 $sport 하기 좋은 날이에요!'
        : score >= 40
            ? '$sport 가능하지만 컨디션을 살피며 하세요.'
            : '오늘은 $sport 대신 다른 운동을 추천해요.';
    return [head, ...tips].join('\n');
  }
}

/// 원형 점수 게이지.
/// [10강] TweenAnimationBuilder: 점수가 바뀌면 이전 값에서 새 값까지 부드럽게 움직인다.
/// AnimationController 없이 쓰는 "암시적(implicit) 애니메이션".
class _ScoreGauge extends StatelessWidget {
  final int score;
  final String sport;

  const _ScoreGauge({required this.score, required this.sport});

  @override
  Widget build(BuildContext context) {
    final color = ScoreColors.of(score);

    return Column(
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: value / 100,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round, // 끝을 둥글게
                      color: color,
                      backgroundColor: color.withAlpha(40),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.round().toString(),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                      Text(ScoreColors.label(score),
                          style: TextStyle(
                              fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text('$sport지수', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 라벨 + 현재 값 + 슬라이더 한 묶음. 항목마다 다른 색을 칠한다.
class _WeatherSlider extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _WeatherSlider({
    required this.icon,
    required this.color,
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
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$label  '),
                    TextSpan(
                      text: '${value.toStringAsFixed(0)}$unit',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                  ]),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        // SliderTheme: 이 슬라이더 하나만 색을 바꾼다 (앱 전체 테마는 그대로)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withAlpha(40),
            thumbColor: color,
            overlayColor: color.withAlpha(30),
          ),
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 요일 동그라미 (월 화 수 ...)
/// [10강] AnimatedContainer: 선택이 바뀌면 크기/테두리/그림자가 부드럽게 변한다.
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: selected ? 44 : 38,
            height: selected ? 44 : 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : color.withAlpha(60),
              shape: BoxShape.circle,
              boxShadow: selected
                  ? [BoxShadow(color: color.withAlpha(110), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 오늘 표시 (PDF의 빨간 체크 ✓ → 작은 점)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isToday ? Theme.of(context).colorScheme.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 범례: ● 좋음
class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
