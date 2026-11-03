/// 화면 주소와 종목 URL 식별자를 한 곳에서 관리한다.
abstract final class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const sports = '/sports';
  static const plan = '/plan';
  static const analysis = '/analysis';
  static const ai = '/ai';

  static const signupName = 'signup';
  static const locationsName = 'locations';

  static const sportLabels = {
    'basketball': '농구',
    'running': '런닝',
    'sailing': '요트',
    'hiking': '등산',
    'kayaking': '카약',
    'cycling': '자전거',
  };

  static String sportId(String label) =>
      sportLabels.entries.firstWhere((entry) => entry.value == label).key;

  /// 로그인 후 돌아갈 주소는 앱 안의 보호된 경로만 허용한다.
  static String? safeReturnTo(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !value.startsWith('/') ||
        value.contains('\\')) {
      return null;
    }
    if ([sports, plan, analysis, ai].contains(uri.path) ||
        RegExp(r'^/sports/[^/]+/locations$').hasMatch(uri.path)) {
      return uri.toString();
    }
    return null;
  }

  static Map<String, String> returnQuery(String? value) {
    final target = safeReturnTo(value);
    return target == null ? {} : {'from': target};
  }
}
