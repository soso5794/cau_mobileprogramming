import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'sport_place.dart';

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 현재 위치를 얻는 계층. 화면은 이 인터페이스만 알고, 테스트에서는 가짜로 바꾼다.
/// (WeatherService / AiGateway와 같은 주입 방식)
abstract interface class LocationService {
  Future<GeoPoint> current();
}

/// geolocator 패키지를 사용하는 실제 구현.
/// 권한 → 위치 서비스 → 좌표 순서로 확인하고, 실패 이유를 한국어로 알려준다.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({
    this.timeout = const Duration(seconds: 12),
  });
  final Duration timeout;

  @override
  Future<GeoPoint> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure('기기의 위치 서비스(GPS)가 꺼져 있어요. 설정에서 켜주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationFailure('위치 권한이 거부되었어요. 기본 위치(중앙대 주변)로 보여드릴게요.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure('위치 권한이 영구 거부되어 있어요. 앱 설정에서 권한을 허용해주세요.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure('위치를 찾는 데 시간이 너무 오래 걸려요. 잠시 후 다시 시도해주세요.');
    } catch (_) {
      throw const LocationFailure('현재 위치를 가져오지 못했어요. 기본 위치로 보여드릴게요.');
    }
  }
}
