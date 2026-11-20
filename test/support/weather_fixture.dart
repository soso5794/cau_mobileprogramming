Map<String, dynamic> weatherFixture() {
  final time = DateTime.utc(2026, 11, 20, 3).millisecondsSinceEpoch ~/ 1000;
  const units = {
    'time': 'unixtime',
    'temperature_2m': '°C',
    'relative_humidity_2m': '%',
    'wind_speed_10m': 'm/s',
    'precipitation': 'mm',
    'precipitation_probability': '%',
  };
  return {
    'current_units': {...units},
    'hourly_units': {...units},
    'current': {
      'time': time + 900,
      'temperature_2m': 20,
      'relative_humidity_2m': 50,
      'wind_speed_10m': 2.0,
      'precipitation': 0,
      'weather_code': 1,
    },
    'hourly': <String, dynamic>{
      'time': List.generate(24, (i) => time + i * 3600),
      'temperature_2m': List.filled(24, 20),
      'relative_humidity_2m': List.filled(24, 50),
      'wind_speed_10m': List.filled(24, 2.0),
      'precipitation': List.generate(24, (i) => i == 1 ? 2.0 : 0.0),
      'precipitation_probability': List.generate(24, (i) => i == 1 ? 80 : 0),
      'weather_code': List.generate(24, (i) => i == 1 ? 61 : 1),
    },
  };
}
