/// 운동분석 화면에 보여줄 날씨 정보 한 묶음.
/// 지금은 더미 데이터로 채우고, 나중에 날씨 API(기상청 등)를 연결할 예정.
class Weather {
  final double temp; // 기온 (℃)        -10 ~ 40
  final double humidity; // 습도 (%)    0 ~ 100
  final double wind; // 바람 (m/s)      0 ~ 20
  final double rain; // 시간당 강수 (mm) 0 ~ 30
  final double dust; // 미세먼지 (㎍/㎥) 0 ~ 150

  const Weather({
    required this.temp,
    required this.humidity,
    required this.wind,
    required this.rain,
    required this.dust,
  });

  /// [5강] 불변 객체(immutable)는 값을 바꿀 때 copyWith로 "새 객체"를 만든다.
  Weather copyWith({
    double? temp,
    double? humidity,
    double? wind,
    double? rain,
    double? dust,
  }) {
    return Weather(
      temp: temp ?? this.temp,
      humidity: humidity ?? this.humidity,
      wind: wind ?? this.wind,
      rain: rain ?? this.rain,
      dust: dust ?? this.dust,
    );
  }

  static const Weather empty =
      Weather(temp: 20, humidity: 50, wind: 3, rain: 0, dust: 30);
}
