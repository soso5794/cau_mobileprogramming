import 'package:flutter/material.dart';

import 'weather_forecast.dart';
import 'weather_service.dart';

class LiveWeatherScreen extends StatefulWidget {
  const LiveWeatherScreen({super.key, required this.service});
  final WeatherService service;
  @override
  State<LiveWeatherScreen> createState() => _LiveWeatherScreenState();
}

class _LiveWeatherScreenState extends State<LiveWeatherScreen> {
  WeatherPlace _place = WeatherPlace.choices.first;
  String _sport = ExerciseConditions.sports.first;
  int _hour = 0;
  late Future<WeatherForecast> _forecast;

  @override
  void initState() {
    super.initState();
    _forecast = widget.service.fetch(_place);
  }

  void _refresh() => setState(() {
    _hour = 0;
    _forecast = widget.service.fetch(_place);
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: FutureBuilder<WeatherForecast>(
        future: _forecast,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          return ListView(
            key: const Key('live-weather-scroll'),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '어디서, 언제 운동할까요?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('대표 지점의 현재 날씨와 24시간 예보를 조회해요.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<WeatherPlace>(
                key: const Key('weather-place'),
                initialValue: _place,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '운동 장소 주변'),
                items: [
                  for (final p in WeatherPlace.choices)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (place) {
                  if (place == null || place == _place) return;
                  _place = place;
                  _refresh();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final sport in ExerciseConditions.sports)
                    ChoiceChip(
                      label: Text(sport),
                      selected: _sport == sport,
                      onSelected: (_) => setState(() => _sport = sport),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('weather-refresh'),
                  onPressed: loading ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('새로고침'),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('선택한 장소의 날씨를 불러오는 중…'),
                    ],
                  ),
                )
              else if (snapshot.hasError)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error is WeatherFailure
                              ? (snapshot.error! as WeatherFailure).message
                              : '날씨를 불러오지 못했어요. 다시 시도해주세요.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (snapshot.hasData)
                ..._results(context, snapshot.data!),
              const SizedBox(height: 20),
              const Text('출처: Open-Meteo · CC BY 4.0\nhttps://open-meteo.com/'),
              const SizedBox(height: 8),
              const Text(
                '현재 날씨도 기상 모델 추정값이에요. 지수는 수업용 규칙이며 '
                '미세먼지·코트 점유·바닥 상태를 반영하지 않아요. 현장 이용 가능 여부는 별도로 확인해주세요.',
              ),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _results(BuildContext context, WeatherForecast data) {
    final scheme = Theme.of(context).colorScheme;
    final selected = data.hours[_hour];
    final evaluation = ExerciseConditions.evaluate(_sport, selected);
    final futureHours = data.hours
        .where((h) => !h.time.isBefore(data.current.time))
        .toList();
    final best = futureHours.isEmpty
        ? null
        : futureHours.reduce(
            (a, b) =>
                ExerciseConditions.evaluate(_sport, a).score >=
                    ExerciseConditions.evaluate(_sport, b).score
                ? a
                : b,
          );
    Widget metric(String label, String value) =>
        Chip(label: Text('$label $value'));
    return [
      Text(
        '${data.place.name} · 현재 날씨',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text('기준 ${koreanWeatherTime(data.current.time)} KST'),
      Wrap(
        spacing: 8,
        children: [
          metric('기온', '${data.current.temperature.toStringAsFixed(1)}°C'),
          metric('습도', '${data.current.humidity.round()}%'),
          metric('바람', '${data.current.wind.toStringAsFixed(1)}m/s'),
        ],
      ),
      Text(
        '조회 완료 ${koreanWeatherTime(data.fetchedAt)} KST',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$_sport · ${koreanWeatherTime(selected.time)} 예보',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${evaluation.score} / 100',
                key: const Key('weather-score'),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const Text('운동 환경지수 · 높을수록 날씨 조건이 양호'),
              const SizedBox(height: 8),
              Text(
                '예상 기온 ${selected.temperature.toStringAsFixed(1)}°C · '
                '습도 ${selected.humidity.round()}%\n'
                '바람 ${selected.wind.toStringAsFixed(1)}m/s · '
                '시간당 강수 ${selected.precipitation.toStringAsFixed(1)}mm\n'
                '강수확률 ${selected.rainProbability!.round()}%',
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('지수 산정 이유'),
                children: [
                  for (final reason in evaluation.reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(reason),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (best != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '앞으로 조회된 시간 중 최고 지수: ${koreanWeatherTime(best.time)} · '
            '${ExerciseConditions.evaluate(_sport, best).score}점\n'
            '이동 시간·운영 시간·조명은 반영하지 않아요.',
          ),
        ),
      const SizedBox(height: 8),
      Text(
        '24시간 예보 · 시간을 눌러 비교',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const Text('날짜와 시간은 모두 한국 시간(KST)이에요.'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var i = 0; i < data.hours.length; i++)
            ChoiceChip(
              key: Key('weather-hour-$i'),
              label: Text(
                '${koreanWeatherTime(data.hours[i].time)}\n'
                '${ExerciseConditions.evaluate(_sport, data.hours[i]).score}점',
              ),
              selected: i == _hour,
              onSelected: (_) => setState(() => _hour = i),
            ),
        ],
      ),
    ];
  }
}
