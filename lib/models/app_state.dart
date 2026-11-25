import 'dart:math';

import 'package:flutter/material.dart'; // ThemeMode 때문에 foundation → material

import 'weather.dart';
import '../ai/ai_gateway.dart';
import '../map/location_service.dart';
import '../members/member_controller.dart';
import '../members/member_repository.dart';
import '../members/member_store.dart';
import '../weather/weather_service.dart';

/// 앱 전체가 공유하는 상태 (5강: ChangeNotifier + Provider 패턴)
///
/// 여러 화면(운동선택, 운동분석, Plan)이 같은 데이터를 봐야 하므로
/// 각 화면이 따로 들고 있지 않고 여기 한 곳에 모은다.
/// 값을 바꾼 뒤에는 반드시 notifyListeners()를 불러야 화면이 다시 그려진다.
class AppState extends ChangeNotifier {
  // ───────────────────────── 상수 ─────────────────────────
  static const List<String> allSports = [
    '농구',
    '런닝',
    '축구',
    '요트',
    '등산',
    '카약',
    '자전거',
  ];
  static const List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  AppState({
    MemberController? members,
    AiGateway? aiGateway,
    WeatherService? weatherService,
    LocationService? locationService,
  }) : aiGateway = aiGateway ?? HttpAiGateway(),
       weatherService = weatherService ?? OpenMeteoWeatherService(),
       locationService = locationService ?? const GeolocatorLocationService(),
       members =
           members ??
           MemberController(MemberRepository(store: MemoryMemberStore())) {
    this.members.addListener(_memberChanged);
  }
  final MemberController members;
  final AiGateway aiGateway;
  final WeatherService weatherService;
  final LocationService locationService; // 지도 탭 "내 위치"
  final ValueNotifier<String> _auth = ValueNotifier('');
  String? _previousId;
  String? get loginId => members.profile?.id;
  String? get userName => members.profile?.nickname;
  Listenable get authChanges => _auth;
  void _memberChanged() {
    if (_previousId != loginId) {
      currentSport = null;
      currentLocation = null;
      _locations.clear();
      _previousId = loginId;
    }
    _auth.value =
        '$loginId:${members.profile?.onboarding}:${members.isOperator}';
    notifyListeners();
  }

  Future<bool> logout() => members.logout();
  @override
  void dispose() {
    members.removeListener(_memberChanged);
    members.dispose();
    aiGateway.close();
    weatherService.close();
    _auth.dispose();
    super.dispose();
  }

  // ───────────────────────── 테마 (라이트/다크) ─────────────────────────
  /// [10강] ThemeMode: light / dark / system(폰 설정 따라감)
  ThemeMode themeMode = ThemeMode.light;

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ───────────────────────── 선호 운동 ─────────────────────────
  List<String> get selectedSports => members.profile?.sports ?? const [];
  Future<bool> setSelectedSports(List<String> sports) async {
    final p = members.profile;
    if (p == null) return false;
    final saved = await members.save(
      p.copyWith(
        sports: sports,
        favorites: p.favorites.intersection(sports.toSet()),
      ),
    );
    if (saved && !sports.contains(currentSport)) {
      currentSport = null;
      currentLocation = null;
      notifyListeners();
    }
    return saved;
  }

  Map<String, String> preferenceOf(String sport) =>
      members.profile?.answers[sport] ?? const {};
  bool hasPreference(String sport) =>
      members.profile?.answers.containsKey(sport) ?? false;
  Future<bool> saveSportPreference(
    String sport,
    Map<String, String> answers,
  ) async {
    final p = members.profile;
    if (p == null) return false;
    return members.save(p.copyWith(answers: {...p.answers, sport: answers}));
  }

  // ───────────────────────── 운동별 자주 가는 위치 ─────────────────────────
  final Map<String, List<String>> _locations = {};

  List<String> locationsOf(String sport) =>
      List.unmodifiable(_locations[sport] ?? const []);

  void addLocation(String sport, String location) {
    final list = _locations.putIfAbsent(sport, () => []);
    if (location.trim().isEmpty || list.contains(location)) return;
    list.add(location.trim());
    notifyListeners();
  }

  void removeLocation(String sport, String location) {
    _locations[sport]?.remove(location);
    if (currentSport == sport && currentLocation == location) {
      currentLocation = null;
    }
    notifyListeners();
  }

  // ───────────────────────── 현재 분석 대상 ─────────────────────────
  String? currentSport;
  String? currentLocation;

  void selectTarget(String sport, String location) {
    currentSport = sport;
    currentLocation = location;
    notifyListeners();
  }

  // ───────────────────────── 날씨 & 운동지수 (더미) ─────────────────────────

  /// (위치, 요일)마다 항상 같은 값이 나오는 가짜 날씨.
  /// TODO: 날씨 API 연결 시 이 함수만 교체하면 된다.
  Weather weatherFor(String location, int dayIndex) {
    final rnd = Random('$location-$dayIndex'.hashCode);
    return Weather(
      temp: 5 + rnd.nextDouble() * 25, // 5~30℃
      humidity: 30 + rnd.nextDouble() * 60, // 30~90%
      wind: rnd.nextDouble() * 12, // 0~12 m/s
      rain: rnd.nextInt(4) == 0 ? rnd.nextDouble() * 10 : 0, // 25% 확률로 비
      dust: 10 + rnd.nextDouble() * 90, // 10~100
    );
  }

  /// 날씨 → 0~100점 운동지수. 매우 단순한 규칙 기반 공식.
  static int scoreFor(String sport, Weather w) {
    double s = 100;
    s -= (w.temp - 20).abs() * 2; // 20℃에서 멀어질수록 감점
    s -= (w.humidity - 50).abs() * 0.3;
    s -= w.rain * 5; // 비는 크게 감점
    s -= w.dust * 0.3;
    if (sport == '요트') {
      s -= (w.wind - 8).abs() * 3; // 요트는 적당한 바람(8m/s 근처)이 좋음
    } else {
      s -= w.wind * 2;
    }
    if (sport == '농구') s += 10; // 실내 코트 대안이 있어 조금 가산
    return s.clamp(0, 100).round();
  }

  /// 해당 운동의 요일별 점수 (저장된 첫 번째 위치 기준). 위치가 없으면 null.
  List<int>? weeklyScores(String sport, {String? location}) {
    final loc =
        location ??
        (locationsOf(sport).isEmpty ? null : locationsOf(sport).first);
    if (loc == null) return null;
    return List.generate(7, (day) => scoreFor(sport, weatherFor(loc, day)));
  }
}
