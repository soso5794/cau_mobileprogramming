import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather_forecast.dart';

class WeatherFailure implements Exception {
  const WeatherFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class WeatherService {
  Future<WeatherForecast> fetch(WeatherPlace place);
  void close();
}

/// 화면에서 주입할 수 있는 HTTP 계층. 실제 앱과 테스트가 같은 파서를 사용한다.
class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;
  final http.Client _client;
  final Duration timeout;
  final DateTime Function() _clock;

  static Uri endpoint(
    WeatherPlace place,
  ) => Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '${place.latitude}',
    'longitude': '${place.longitude}',
    'current':
        'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m',
    'hourly':
        'temperature_2m,relative_humidity_2m,precipitation,precipitation_probability,weather_code,wind_speed_10m',
    'forecast_hours': '24',
    'timezone': 'Asia/Seoul',
    'timeformat': 'unixtime',
    'temperature_unit': 'celsius',
    'wind_speed_unit': 'ms',
    'precipitation_unit': 'mm',
  });

  @override
  Future<WeatherForecast> fetch(WeatherPlace place) async {
    try {
      final response = await _client.get(endpoint(place)).timeout(timeout);
      if (response.statusCode == 429) {
        throw const WeatherFailure('요청이 많아 잠시 제한되었어요. 잠시 후 다시 시도해주세요.');
      }
      if (response.statusCode != 200) {
        throw WeatherFailure(
          '날씨 서버 응답 오류 (${response.statusCode}). 다시 시도해주세요.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid weather response');
      }
      return WeatherForecast.fromJson(
        decoded,
        place: place,
        fetchedAt: _clock(),
      );
    } on TimeoutException {
      throw const WeatherFailure('날씨 요청 시간이 초과되었어요. 연결을 확인하고 다시 시도해주세요.');
    } on http.ClientException {
      throw const WeatherFailure('날씨 서버에 연결하지 못했어요. 인터넷 연결을 확인해주세요.');
    } on FormatException {
      throw const WeatherFailure('날씨 응답 형식이 올바르지 않아요. 잠시 후 다시 시도해주세요.');
    }
  }

  @override
  void close() => _client.close();
}
