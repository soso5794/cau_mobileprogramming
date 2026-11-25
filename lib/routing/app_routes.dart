/// 화면 주소와 종목 URL 식별자를 한 곳에서 관리한다.
abstract final class AppRoutes {
  static const demo = '/demo';
  static const admin = '/admin';
  static const operatorLogin = '/operator-login';
  static const reset = '/password-reset';
  static const onboarding = '/onboarding';
  static const editProfile = '/me/edit';
  static const settings = '/me/settings';
  static const notifications = '/me/settings/notifications';
  static const teams = '/me/teams';
  static const applications = '/me/applications';
  static const login = '/login';
  static const signup = '/signup';
  static const sports = '/sports'; // 홈 대시보드 (기존 주소 유지)
  static const match = '/match'; // 이전 링크 호환
  static const community = '/community';
  static const map = '/map';
  static const ranking = '/ranking';
  static const me = '/me';

  // 기존 기능 경로는 하위 페이지로 유지한다.
  static const plan = '/plan';
  static const analysis = '/analysis';
  static const ai = '/ai';
  static const planPage = '/me/plan';
  static const analysisPage = '/me/analysis';
  static const aiPage = '/me/ai';
  static const weatherPage = '/me/weather';

  static const signupName = 'signup';
  static const locationsName = 'locations';
  static const setupName = 'sport-setup';

  static const sportLabels = {
    'basketball': '농구',
    'running': '런닝',
    'soccer': '축구',
    'sailing': '요트',
    'hiking': '등산',
    'kayaking': '카약',
    'cycling': '자전거',
  };

  static String recruitmentCreate(String sport) => '/community/${sportId(sport)}/create';

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
    const staticPaths = [
      admin,
      sports,
      match,
      community,
      map,
      ranking,
      me,
      plan,
      analysis,
      ai,
      planPage,
      analysisPage,
      aiPage,
      weatherPage,
      editProfile,
      settings,
      notifications,
      teams,
      applications,
    ];
    if (staticPaths.contains(uri.path) ||
        RegExp(r'^/sports/[^/]+/(locations|setup)$').hasMatch(uri.path) ||
        RegExp(r'^/community/(posts/[^/]+|[^/]+(?:/create)?)$').hasMatch(uri.path) ||
        RegExp(r'^/admin/member/[^/]+$').hasMatch(uri.path)) {
      return uri.toString();
    }
    return null;
  }

  static Map<String, String> returnQuery(String? value) {
    final target = safeReturnTo(value);
    return target == null ? {} : {'from': target};
  }
}
