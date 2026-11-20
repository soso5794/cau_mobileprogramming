import 'dart:async';
import 'dart:convert';

import 'package:exercise_assist/weather/weather_forecast.dart';
import 'package:exercise_assist/weather/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/weather_fixture.dart';

void main() {
  final place = WeatherPlace.choices.first;
  final now = DateTime.utc(2026, 11, 20, 3, 15);
  test(
    'HTTPS GET uses selected coordinates and explicit units; parses JSON',
    () async {
      final service = OpenMeteoWeatherService(
        clock: () => now,
        client: MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.url.scheme, 'https');
          expect(r.url.host, 'api.open-meteo.com');
          expect(r.url.queryParameters['latitude'], '${place.latitude}');
          expect(r.url.queryParameters['longitude'], '${place.longitude}');
          expect(r.url.queryParameters['wind_speed_unit'], 'ms');
          expect(r.url.queryParameters['forecast_hours'], '24');
          expect(r.url.queryParameters['timeformat'], 'unixtime');
          expect(r.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode(weatherFixture()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);
      final data = await service.fetch(place);
      expect(data.hours, hasLength(24));
      expect(data.current.temperature, 20);
      expect(data.hours[1].rainProbability, 80);
      expect(data.hours[1].precipitation, 2);
      expect(data.fetchedAt, now);
      expect(koreanWeatherTime(data.hours.first.time), '11/20 12:00');
      expect(koreanWeatherTime(data.hours.last.time), '11/21 11:00');
    },
  );
  for (final status in [429, 500]) {
    test('HTTP $status reports failure instead of demo data', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient((_) async => http.Response('failed', status)),
      );
      addTearDown(service.close);
      await expectLater(service.fetch(place), throwsA(isA<WeatherFailure>()));
    });
  }
  test('network failure is actionable', () async {
    final service = OpenMeteoWeatherService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(service.close);
    await expectLater(
      service.fetch(place),
      throwsA(
        isA<WeatherFailure>().having(
          (e) => e.message,
          'message',
          contains('인터넷'),
        ),
      ),
    );
  });
  test('timeout does not leave loading forever', () async {
    final service = OpenMeteoWeatherService(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.close);
    await expectLater(
      service.fetch(place),
      throwsA(
        isA<WeatherFailure>().having(
          (e) => e.message,
          'message',
          contains('시간이 초과'),
        ),
      ),
    );
  });
  for (final defect in [
    'json',
    'missing',
    'null',
    'length',
    'units',
    'order',
    'range',
  ]) {
    test('invalid $defect response is rejected', () async {
      final fixture = weatherFixture();
      final hourly = fixture['hourly'] as Map<String, dynamic>;
      switch (defect) {
        case 'missing':
          fixture.remove('current');
        case 'null':
          hourly['temperature_2m'] = [null, ...List.filled(23, 20)];
        case 'length':
          hourly['wind_speed_10m'] = [2.0];
        case 'units':
          (fixture['hourly_units'] as Map<String, dynamic>)['wind_speed_10m'] =
              'km/h';
        case 'order':
          (hourly['time'] as List<dynamic>)[1] =
              (hourly['time'] as List<dynamic>)[0];
        case 'range':
          (hourly['relative_humidity_2m'] as List<dynamic>)[0] = 105;
      }
      final service = OpenMeteoWeatherService(
        client: MockClient(
          (_) async => http.Response(
            defect == 'json' ? '<html>error</html>' : jsonEncode(fixture),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(service.close);
      await expectLater(service.fetch(place), throwsA(isA<WeatherFailure>()));
    });
  }
  test('sport-specific rain penalty, extreme cap and score bounds', () {
    WeatherSample sample({double rain = 0, double wind = 2, int code = 1}) =>
        WeatherSample(
          time: now,
          temperature: 20,
          humidity: 50,
          wind: wind,
          precipitation: rain,
          code: code,
          rainProbability: 0,
        );
    final basketball = ExerciseConditions.evaluate('농구', sample(rain: 2));
    final running = ExerciseConditions.evaluate('런닝', sample(rain: 2));
    expect(basketball.score, lessThan(running.score));
    expect(ExerciseConditions.evaluate('농구', sample()).score, 94);
    expect(
      ExerciseConditions.evaluate('농구', sample(code: 95)).score,
      lessThanOrEqualTo(20),
    );
    expect(
      ExerciseConditions.evaluate('축구', sample(code: 71)).score,
      lessThanOrEqualTo(20),
    );
    expect(
      ExerciseConditions.evaluate('런닝', sample(rain: 100, wind: 50)).score,
      0,
    );
    expect(
      () => ExerciseConditions.evaluate('unknown', sample()),
      throwsArgumentError,
    );
  });
}
