import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_state.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/home_shell.dart';
import '../screens/location_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/route_error_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/sport_select_screen.dart';
import 'app_routes.dart';

GoRouter createAppRouter(AppState app, {String? initialLocation}) {
  // 회원가입 push/pop도 주소창에 표시한다.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    // 회원가입/테마/장소 변경은 push 중인 화면을 다시 해석하지 않는다.
    refreshListenable: app.authChanges,
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublic = path == AppRoutes.login || path == AppRoutes.signup;
      // 기존 제출의 /, /home 링크도 새 운동 선택 화면으로 연결한다.
      if (path == '/' || path == '/home') return AppRoutes.sports;
      if (app.loginId == null && !isPublic) {
        return Uri(
          path: AppRoutes.login,
          queryParameters: AppRoutes.returnQuery(state.uri.toString()),
        ).toString();
      }
      if (app.loginId != null && isPublic) {
        return AppRoutes.safeReturnTo(state.uri.queryParameters['from']) ??
            AppRoutes.sports;
      }
      return null;
    },
    errorBuilder: (context, state) => const RouteErrorScreen(),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.sports),
      GoRoute(path: '/home', redirect: (context, state) => AppRoutes.sports),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: AppRoutes.signupName,
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sports,
                builder: (context, state) => const SportSelectScreen(),
                routes: [
                  GoRoute(
                    path: ':sport/locations',
                    name: AppRoutes.locationsName,
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final sport =
                          AppRoutes.sportLabels[state.pathParameters['sport']];
                      return sport == null
                          ? const RouteErrorScreen(message: '지원하지 않는 운동 종목이에요.')
                          : LocationScreen(sport: sport);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.plan,
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analysis,
                builder: (context, state) => const AnalysisScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ai,
                builder: (context, state) => const AiChatScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) =>
            NotificationSettingsScreen(key: ValueKey(app.loginId)),
      ),
    ],
  );
}
