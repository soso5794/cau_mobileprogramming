import 'dart:math' as math;

import '../weather/weather_forecast.dart';

/// 지도에 표시하는 운동 장소 한 곳.
///
/// 좌표는 공원·운동장의 "대략적인 위치"이며 코트 예약/점유 상태를 뜻하지 않는다.
/// 나중에 서버(모집글 DB)가 생기면 같은 모양의 데이터를 서버에서 받아오면 된다.
class SportPlace {
  const SportPlace({
    required this.id,
    required this.name,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.sports,
    required this.kind,
    this.note = '',
  });

  final String id;
  final String name;
  final String area; // 자치구 등 짧은 지역명
  final double latitude, longitude;
  final List<String> sports; // '농구' / '런닝' / '축구'
  final String kind; // 실외 코트, 축구장, 러닝 코스 ...
  final String note;

  bool supports(String sport) => sports.contains(sport);

  /// 기존 날씨 서비스(OpenMeteoWeatherService.fetch)를 그대로 재사용하기 위한 변환.
  WeatherPlace toWeatherPlace() => WeatherPlace(name, latitude, longitude);
}

/// 위도/경도 한 쌍. (패키지 LatLng에 의존하지 않아 순수 Dart 테스트가 가능하다.)
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
}

/// 두 지점 사이 직선 거리(km). 하버사인(Haversine) 공식.
double distanceKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(h));
}

/// 화면용 거리 문자열: 1km 미만은 m, 그 이상은 소수 한 자리 km.
String formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(1)}km';

/// 지도 탭에서 쓰는 장소 목록과 검색/정렬 규칙.
abstract final class SportPlaces {
  /// 기본 지도 중심: 중앙대 서울캠퍼스 주변 (기존 WeatherPlace와 같은 좌표).
  static const defaultCenter = GeoPoint(37.5053, 126.9571);

  /// 지도에서 다루는 종목. 날씨 지수(ExerciseConditions)가 지원하는 종목과 같다.
  static const mapSports = ExerciseConditions.sports;

  static const all = <SportPlace>[
    SportPlace(
      id: 'cau',
      name: '중앙대 서울캠퍼스 운동장',
      area: '동작구',
      latitude: 37.5053,
      longitude: 126.9571,
      sports: ['축구', '런닝'],
      kind: '학교 운동장',
      note: '학교 일정에 따라 개방 시간이 달라질 수 있어요.',
    ),
    SportPlace(
      id: 'boramae',
      name: '보라매공원',
      area: '동작구',
      latitude: 37.4925,
      longitude: 126.9200,
      sports: ['런닝', '축구', '농구'],
      kind: '공원 · 운동장',
      note: '트랙 러닝과 인조잔디 운동장이 함께 있어요.',
    ),
    SportPlace(
      id: 'nodeul',
      name: '노들섬',
      area: '용산구',
      latitude: 37.5175,
      longitude: 126.9580,
      sports: ['런닝'],
      kind: '러닝 코스',
      note: '한강대교를 건너는 짧은 순환 코스로 좋아요.',
    ),
    SportPlace(
      id: 'ichon',
      name: '이촌한강공원',
      area: '용산구',
      latitude: 37.5180,
      longitude: 126.9700,
      sports: ['런닝', '농구', '축구'],
      kind: '한강공원',
    ),
    SportPlace(
      id: 'yeouido',
      name: '여의도한강공원',
      area: '영등포구',
      latitude: 37.5283,
      longitude: 126.9326,
      sports: ['런닝', '농구'],
      kind: '한강공원',
      note: '러닝 크루가 많이 모이는 대표 코스예요.',
    ),
    SportPlace(
      id: 'banpo',
      name: '반포한강공원',
      area: '서초구',
      latitude: 37.5100,
      longitude: 126.9960,
      sports: ['런닝'],
      kind: '러닝 코스',
    ),
    SportPlace(
      id: 'hyochang',
      name: '효창운동장',
      area: '용산구',
      latitude: 37.5440,
      longitude: 126.9606,
      sports: ['축구'],
      kind: '축구장',
    ),
    SportPlace(
      id: 'namsan',
      name: '남산 둘레길',
      area: '중구',
      latitude: 37.5512,
      longitude: 126.9882,
      sports: ['런닝'],
      kind: '러닝 코스',
      note: '오르막이 있어 인터벌·언덕 훈련에 좋아요.',
    ),
    SportPlace(
      id: 'jangchung',
      name: '장충체육관 주변',
      area: '중구',
      latitude: 37.5583,
      longitude: 127.0068,
      sports: ['농구'],
      kind: '실내 체육관',
      note: '실내 시설이라 비 오는 날 대안으로 확인해보세요.',
    ),
    SportPlace(
      id: 'mangwon',
      name: '망원한강공원',
      area: '마포구',
      latitude: 37.5550,
      longitude: 126.8960,
      sports: ['런닝', '농구', '축구'],
      kind: '한강공원',
    ),
    SportPlace(
      id: 'worldcup',
      name: '서울월드컵경기장 주변',
      area: '마포구',
      latitude: 37.5683,
      longitude: 126.8973,
      sports: ['축구', '런닝'],
      kind: '축구장',
    ),
    SportPlace(
      id: 'seoulforest',
      name: '서울숲',
      area: '성동구',
      latitude: 37.5444,
      longitude: 127.0374,
      sports: ['런닝'],
      kind: '공원',
    ),
    SportPlace(
      id: 'ttukseom',
      name: '뚝섬한강공원',
      area: '광진구',
      latitude: 37.5296,
      longitude: 127.0670,
      sports: ['런닝', '농구'],
      kind: '한강공원',
    ),
    SportPlace(
      id: 'jamsil',
      name: '잠실종합운동장 주변',
      area: '송파구',
      latitude: 37.5157,
      longitude: 127.0728,
      sports: ['축구', '농구', '런닝'],
      kind: '종합운동장',
    ),
    SportPlace(
      id: 'olympic',
      name: '올림픽공원',
      area: '송파구',
      latitude: 37.5206,
      longitude: 127.1214,
      sports: ['런닝'],
      kind: '공원',
      note: '평지 순환로가 길어 장거리 러닝에 좋아요.',
    ),
  ];

  static SportPlace? byName(String name) {
    for (final place in all) {
      if (place.name == name) return place;
    }
    return null;
  }

  /// [sport]가 null이면 전체, 아니면 해당 종목 장소만.
  /// [origin](내 위치)이 있으면 가까운 순으로 정렬한다.
  static List<SportPlace> visible({String? sport, GeoPoint? origin}) {
    final list = [
      for (final place in all)
        if (sport == null || place.supports(sport)) place,
    ];
    if (origin != null) {
      list.sort(
        (a, b) => distanceKm(
          origin,
          GeoPoint(a.latitude, a.longitude),
        ).compareTo(distanceKm(origin, GeoPoint(b.latitude, b.longitude))),
      );
    }
    return List.unmodifiable(list);
  }
}
