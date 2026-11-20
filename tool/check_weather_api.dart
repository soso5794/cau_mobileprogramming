import 'dart:io';

import 'package:exercise_assist/weather/weather_forecast.dart';
import 'package:exercise_assist/weather/weather_service.dart';

/// 실제 앱과 같은 HTTP 클라이언트/파서를 사용한다. 회원정보는 전송하지 않는다.
Future<void> main() async {
  final service = OpenMeteoWeatherService();
  try {
    final data = await service.fetch(WeatherPlace.choices.first);
    stdout.writeln('HTTPS GET success: ${data.place.name}');
    stdout.writeln(
      'Current: ${koreanWeatherTime(data.current.time)} KST, '
      '${data.current.temperature}°C, ${data.current.wind}m/s',
    );
    stdout.writeln(
      'Hourly samples: ${data.hours.length}, '
      '${koreanWeatherTime(data.hours.first.time)} – ${koreanWeatherTime(data.hours.last.time)} KST',
    );
  } catch (error) {
    stderr.writeln('Weather API verification failed: $error');
    exitCode = 1;
  } finally {
    service.close();
  }
}
