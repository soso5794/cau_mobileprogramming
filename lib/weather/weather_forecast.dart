/// 고정된 대표 지점. GPS나 코트 예약/점유 상태를 의미하지 않는다.
class WeatherPlace {
  const WeatherPlace(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude, longitude;
  static const choices = [
    WeatherPlace('중앙대 서울캠퍼스 주변', 37.5053, 126.9571),
    WeatherPlace('잠실종합운동장 주변', 37.5157, 127.0728),
    WeatherPlace('여의도 한강공원 주변', 37.5283, 126.9326),
    WeatherPlace('부산 시민공원 주변', 35.1684, 129.0576),
  ];
}

class WeatherSample {
  const WeatherSample({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.wind,
    required this.precipitation,
    required this.code,
    this.rainProbability,
  });
  final DateTime time; // UTC instant, rendered explicitly in KST.
  final double temperature, humidity, wind, precipitation;
  final int code;
  final double? rainProbability;
}

class WeatherForecast {
  const WeatherForecast({
    required this.place,
    required this.current,
    required this.hours,
    required this.fetchedAt,
  });
  final WeatherPlace place;
  final WeatherSample current;
  final List<WeatherSample> hours;
  final DateTime fetchedAt;

  factory WeatherForecast.fromJson(
    Map<String, dynamic> json, {
    required WeatherPlace place,
    required DateTime fetchedAt,
  }) {
    Map<String, dynamic> object(Object? value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Missing weather object');
      }
      return value;
    }

    double number(Object? value, double min, double max) {
      if (value is! num || !value.isFinite || value < min || value > max) {
        throw const FormatException('Invalid weather value');
      }
      return value.toDouble();
    }

    DateTime instant(Object? value) => DateTime.fromMillisecondsSinceEpoch(
      (number(value, 0, 4102444800) * 1000).round(),
      isUtc: true,
    );

    final current = object(json['current']);
    final hourly = object(json['hourly']);
    final currentUnits = object(json['current_units']);
    final hourlyUnits = object(json['hourly_units']);
    for (final units in [currentUnits, hourlyUnits]) {
      if (units['time'] != 'unixtime' ||
          units['temperature_2m'] != '°C' ||
          units['wind_speed_10m'] != 'm/s' ||
          units['relative_humidity_2m'] != '%' ||
          units['precipitation'] != 'mm') {
        throw const FormatException('Unexpected weather units');
      }
    }
    if (hourlyUnits['precipitation_probability'] != '%') {
      throw const FormatException('Unexpected probability unit');
    }
    final times = hourly['time'];
    if (times is! List || times.isEmpty || times.length > 48) {
      throw const FormatException('Missing hourly forecast');
    }
    const fields = [
      'temperature_2m',
      'relative_humidity_2m',
      'wind_speed_10m',
      'precipitation',
      'precipitation_probability',
      'weather_code',
    ];
    for (final key in fields) {
      final values = hourly[key];
      if (values is! List || values.length != times.length) {
        throw const FormatException('Incomplete hourly forecast');
      }
    }
    WeatherSample sample(Map<String, dynamic> row, {bool hourly = false}) {
      final code = number(row['weather_code'], 0, 99);
      if (code != code.roundToDouble()) {
        throw const FormatException('Invalid weather code');
      }
      return WeatherSample(
        time: instant(row['time']),
        temperature: number(row['temperature_2m'], -100, 70),
        humidity: number(row['relative_humidity_2m'], 0, 100),
        wind: number(row['wind_speed_10m'], 0, 150),
        precipitation: number(row['precipitation'], 0, 2000),
        code: code.toInt(),
        rainProbability: hourly
            ? number(row['precipitation_probability'], 0, 100)
            : null,
      );
    }

    final hours = List.generate(
      times.length,
      (i) => sample({
        'time': times[i],
        for (final key in fields) key: (hourly[key] as List<dynamic>)[i],
      }, hourly: true),
    );
    for (var i = 1; i < hours.length; i++) {
      if (hours[i].time.difference(hours[i - 1].time) !=
          const Duration(hours: 1)) {
        throw const FormatException('Invalid hourly order');
      }
    }
    return WeatherForecast(
      place: place,
      current: sample(current),
      hours: List.unmodifiable(hours),
      fetchedAt: fetchedAt.toUtc(),
    );
  }
}

/// 기기의 시간대와 무관하게 예보 지점의 한국 시간을 표시한다.
String koreanWeatherTime(DateTime instant) {
  final kst = instant.toUtc().add(const Duration(hours: 9));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${kst.month}/${kst.day} ${two(kst.hour)}:${two(kst.minute)}';
}

/// 수업용 설명 가능한 규칙 지수. 공식 기상지수나 안전 보장이 아니다.
class ExerciseConditions {
  const ExerciseConditions(this.score, this.reasons);
  final int score;
  final List<String> reasons;
  static const sports = ['농구', '런닝', '축구'];

  factory ExerciseConditions.evaluate(String sport, WeatherSample hour) {
    if (!sports.contains(sport)) throw ArgumentError.value(sport, 'sport');
    final basketball = sport == '농구';
    final ideal = basketball ? 20 : 18;
    final temperaturePenalty = (hour.temperature - ideal).abs() * 2;
    final humidityPenalty = (hour.humidity - 65).clamp(0, 35) * 0.4;
    final windPenalty = hour.wind * (basketball ? 3 : 2);
    final rainPenalty = hour.precipitation * (basketball ? 18 : 10);
    final probabilityPenalty = (hour.rainProbability ?? 0) * 0.1;
    var score =
        (100 -
                temperaturePenalty -
                humidityPenalty -
                windPenalty -
                rainPenalty -
                probabilityPenalty)
            .clamp(0, 100)
            .round();
    final reasons = <String>[
      '기온 기준 $ideal°C · 차이 ${temperaturePenalty.toStringAsFixed(1)}점 감점',
      '바람 ${hour.wind.toStringAsFixed(1)}m/s · ${windPenalty.toStringAsFixed(1)}점 감점',
      '시간당 강수 ${hour.precipitation.toStringAsFixed(1)}mm · ${rainPenalty.toStringAsFixed(1)}점 감점',
      '습도 ${humidityPenalty.toStringAsFixed(1)}점 / 강수확률 ${probabilityPenalty.toStringAsFixed(1)}점 감점',
    ];
    if (hour.code >= 95 ||
        hour.wind >= 15 ||
        hour.temperature >= 35 ||
        hour.temperature <= -10 ||
        [56, 57, 66, 67, 71, 73, 75, 77, 85, 86].contains(hour.code)) {
      score = score.clamp(0, 20);
      reasons.add('뇌우·눈/결빙성 강수·강풍·극한 기온 조건은 최대 20점으로 제한');
    }
    if (basketball && hour.precipitation > 0) {
      reasons.add('농구는 젖은 코트의 영향이 커 강수 감점을 높게 적용');
    }
    return ExerciseConditions(score, List.unmodifiable(reasons));
  }
}
