import 'package:exercise_assist/map/location_service.dart';
import 'package:exercise_assist/map/sport_place.dart';
import 'package:exercise_assist/weather/weather_forecast.dart';
import 'package:exercise_assist/weather/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/member_test_support.dart';
import 'support/weather_fixture.dart';

/// 즉시 고정 예보를 돌려주는 가짜 날씨 서비스 (네트워크 없음).
class FixtureWeatherService implements WeatherService {
  final requested = <WeatherPlace>[];
  @override
  Future<WeatherForecast> fetch(WeatherPlace place) async {
    requested.add(place);
    return WeatherForecast.fromJson(
      weatherFixture(),
      place: place,
      fetchedAt: DateTime.utc(2026, 11, 20, 3, 15),
    );
  }

  @override
  void close() {}
}

class FakeLocationService implements LocationService {
  FakeLocationService(this.result);
  final Object result; // GeoPoint 또는 LocationFailure
  @override
  Future<GeoPoint> current() async {
    final r = result;
    if (r is GeoPoint) return r;
    throw r;
  }
}

Future<void> openMap(WidgetTester tester, {LocationService? location}) async {
  final app = makeApp(
    weatherService: FixtureWeatherService(),
    locationService: location ?? FakeLocationService(SportPlaces.defaultCenter),
  );
  final router = await openApp(tester, app);
  await demoLogin(tester);
  router.go('/map');
  await tester.pumpAndSettle();
}

void main() {
  group('SportPlaces (순수 로직)', () {
    test('장소 id는 겹치지 않고, 좌표는 국내 범위, 종목은 지도 지원 종목만', () {
      final ids = SportPlaces.all.map((p) => p.id).toSet();
      expect(ids.length, SportPlaces.all.length);
      for (final p in SportPlaces.all) {
        expect(p.latitude, inInclusiveRange(33, 39));
        expect(p.longitude, inInclusiveRange(124, 132));
        expect(p.sports, isNotEmpty);
        expect(p.sports.every(SportPlaces.mapSports.contains), isTrue);
      }
    });

    test('하버사인 거리: 같은 점은 0, 중앙대→잠실은 약 10km', () {
      const cau = GeoPoint(37.5053, 126.9571);
      const jamsil = GeoPoint(37.5157, 127.0728);
      expect(distanceKm(cau, cau), 0);
      expect(distanceKm(cau, jamsil), closeTo(10.3, 0.5));
      expect(distanceKm(cau, jamsil), closeTo(distanceKm(jamsil, cau), 1e-9));
    });

    test('거리 표시: 1km 미만은 m, 이상은 km', () {
      expect(formatDistance(0.35), '350m');
      expect(formatDistance(2.345), '2.3km');
    });

    test('종목 필터와 가까운 순 정렬', () {
      final soccer = SportPlaces.visible(sport: '축구');
      expect(soccer, isNotEmpty);
      expect(soccer.every((p) => p.supports('축구')), isTrue);
      expect(SportPlaces.visible().length, SportPlaces.all.length);

      const jamsil = GeoPoint(37.5157, 127.0728);
      final sorted = SportPlaces.visible(origin: jamsil);
      expect(sorted.first.id, 'jamsil');
      for (var i = 1; i < sorted.length; i++) {
        double d(SportPlace p) =>
            distanceKm(jamsil, GeoPoint(p.latitude, p.longitude));
        expect(d(sorted[i]), greaterThanOrEqualTo(d(sorted[i - 1])));
      }
    });
  });

  testWidgets('마커를 누르면 날씨 지수가 보이고 내 장소로 저장된다', (tester) async {
    await openMap(tester);
    await tester.tap(find.byKey(const ValueKey('marker-cau')));
    await tester.pumpAndSettle();

    expect(find.text('중앙대 서울캠퍼스 운동장'), findsWidgets);
    // 고정 예보(20°C, 바람 2m/s, 비 없음) → 축구/런닝 92점
    expect(find.text('92점 · 좋음'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('save-cau-축구')));
    await tester.pumpAndSettle();
    final chip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('save-cau-축구')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('내 위치를 받으면 가까운 순으로 카드가 정렬된다', (tester) async {
    await openMap(
      tester,
      location: FakeLocationService(const GeoPoint(37.5157, 127.0728)),
    );
    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(find.text('0m · 종합운동장'), findsOneWidget);
  });

  testWidgets('위치 권한 실패는 스낵바로 안내한다', (tester) async {
    await openMap(
      tester,
      location: FakeLocationService(const LocationFailure('위치 권한이 거부되었어요.')),
    );
    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한이 거부되었어요.'), findsOneWidget);
  });
}
