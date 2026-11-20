import 'dart:async';

import 'package:exercise_assist/main.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/weather/live_weather_screen.dart';
import 'package:exercise_assist/weather/weather_forecast.dart';
import 'package:exercise_assist/weather/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/weather_fixture.dart';

class ControlledWeatherService implements WeatherService {
  final requests = <(WeatherPlace, Completer<WeatherForecast>)>[];
  @override
  Future<WeatherForecast> fetch(WeatherPlace place) {
    final completer = Completer<WeatherForecast>();
    requests.add((place, completer));
    return completer.future;
  }

  void succeed(int i) => requests[i].$2.complete(
    WeatherForecast.fromJson(
      weatherFixture(),
      place: requests[i].$1,
      fetchedAt: DateTime.utc(2026, 11, 20, 3, 15),
    ),
  );
  @override
  void close() {}
}

Future<void> showWeather(
  WidgetTester tester,
  ControlledWeatherService service, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: scale > 1 ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: LiveWeatherScreen(service: service)),
    ),
  );
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'loading, error, retry, success, refresh and no duplicate request on sport change',
    (tester) async {
      final service = ControlledWeatherService();
      await showWeather(tester, service);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.requests.first.$2.completeError(
        const WeatherFailure('인터넷 연결을 확인해주세요.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('인터넷 연결을 확인해주세요.'), findsOneWidget);
      expect(find.byKey(const Key('weather-score')), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      service.succeed(1);
      await tester.pumpAndSettle();
      expect(find.text('중앙대 서울캠퍼스 주변 · 현재 날씨'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '런닝'));
      await tester.pumpAndSettle();
      expect(service.requests, hasLength(2));
      await tester.tap(find.byKey(const Key('weather-refresh')));
      await tester.pump();
      expect(service.requests, hasLength(3));
      expect(find.byKey(const Key('weather-score')), findsNothing);
      service.succeed(2);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weather-hour-1')),
        200,
      );
      await tester.tap(find.byKey(const Key('weather-hour-1')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weather-score')),
        -200,
      );
      await tester.pumpAndSettle();
      expect(find.text('64 / 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late response from old place cannot replace selected place', (
    tester,
  ) async {
    final service = ControlledWeatherService();
    await showWeather(tester, service);
    await tester.tap(find.byKey(const Key('weather-place')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('잠실종합운동장 주변').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.requests, hasLength(2));
    service.succeed(1);
    await tester.pumpAndSettle();
    service.succeed(0);
    await tester.pumpAndSettle();
    expect(find.text('잠실종합운동장 주변 · 현재 날씨'), findsOneWidget);
    expect(find.text('중앙대 서울캠퍼스 주변 · 현재 날씨'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('pending response after screen disposal is ignored', (
    tester,
  ) async {
    final service = ControlledWeatherService();
    await showWeather(tester, service);
    await tester.pumpWidget(const SizedBox.shrink());
    service.succeed(0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'small screen and 200 percent dark text can scroll without overflow',
    (tester) async {
      final service = ControlledWeatherService();
      await showWeather(tester, service, scale: 2);
      service.succeed(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('지수 산정 이유'), 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('지수 산정 이유'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지수 산정 이유'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weather-hour-23')),
        300,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('home entry uses real app route and returns to my page', (
    tester,
  ) async {
    final service = ControlledWeatherService();
    final app = AppState(weatherService: service);
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const ExerciseAssistApp(initialLocation: '/sports'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('실시간 운동 날씨'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    service.succeed(0);
    await tester.pumpAndSettle();
    expect(find.byType(LiveWeatherScreen), findsOneWidget);
    expect(find.text('실시간 운동 날씨'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('내정보'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
