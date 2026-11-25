import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../admin/admin_screen.dart';
import '../admin/operator_login_screen.dart';
import '../members/account_support_screens.dart';
import '../members/profile_editor_screen.dart';
import '../members/settings_screen.dart';
import '../members/team_screens.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/feature_page.dart';
import '../screens/home_shell.dart';
import '../screens/home_dashboard_screen.dart';
import '../community/recruitment_card.dart';
import '../screens/location_screen.dart';
import '../screens/login_screen.dart';
import '../screens/map_screen.dart';
import '../screens/match_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/route_error_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/sport_select_screen.dart';
import '../screens/sport_setup_screen.dart';
import '../weather/live_weather_screen.dart';
import 'app_routes.dart';

GoRouter createAppRouter(AppState app, {String? initialLocation}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: app.authChanges,
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == AppRoutes.match) return AppRoutes.community;
      if (path == '/' || path == '/home') return AppRoutes.sports;
      // 이전 버전의 링크를 새 하단 메뉴 구조 안으로 연결한다.
      if (path == AppRoutes.plan) return AppRoutes.planPage;
      if (path == AppRoutes.analysis) return AppRoutes.analysisPage;
      if (path == AppRoutes.ai) return AppRoutes.aiPage;

      final isPublic = [
        AppRoutes.operatorLogin,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.demo,
        AppRoutes.reset,
      ].contains(path);
      if (app.loginId == null && !isPublic) {
        return Uri(
          path: AppRoutes.login,
          queryParameters: AppRoutes.returnQuery(state.uri.toString()),
        ).toString();
      }
      if (app.loginId != null &&
          (path == AppRoutes.admin || path.startsWith('/admin/')) &&
          !app.members.isOperator) {
        return AppRoutes.me;
      }
      if (app.loginId != null &&
          app.members.profile!.onboarding == 'pending' &&
          path != AppRoutes.onboarding) {
        return Uri(
          path: AppRoutes.onboarding,
          queryParameters: AppRoutes.returnQuery(
            isPublic ? state.uri.queryParameters['from'] : state.uri.toString(),
          ),
        ).toString();
      }
      if (app.loginId != null && isPublic) {
        if (app.members.isOperator) {
          return AppRoutes.admin;
        }
        return AppRoutes.safeReturnTo(state.uri.queryParameters['from']) ??
            AppRoutes.sports;
      }
      return null;
    },
    errorBuilder: (context, state) => const RouteErrorScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.operatorLogin,
        builder: (context, state) => const OperatorLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminScreen(),
        routes: [
          GoRoute(
            path: 'member/:id',
            builder: (context, state) {
              final p = app.members.managedMembers
                  .where((p) => p.id == state.pathParameters['id'])
                  .firstOrNull;
              return p == null
                  ? const RouteErrorScreen(message: '회원을 찾을 수 없어요.')
                  : ProfileEditorScreen(
                      key: ValueKey('managed-${p.id}'),
                      managedProfile: p,
                    );
            },
          ),
        ],
      ),
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
      GoRoute(
        path: AppRoutes.demo,
        builder: (context, state) => const DemoAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.reset,
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) =>
            ProfileEditorScreen(key: ValueKey(app.loginId), onboarding: true),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) =>
            ProfileEditorScreen(key: ValueKey(app.loginId)),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const MemberSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) =>
            NotificationSettingsScreen(key: ValueKey(app.loginId)),
      ),
      GoRoute(
        path: AppRoutes.teams,
        builder: (context, state) => const MemberTeamsScreen(),
      ),
      GoRoute(
        path: AppRoutes.applications,
        builder: (context, state) => const ApplicationsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          // 홈: 랭킹·개인 일정·관심 종목 추천 모집을 모아 보여준다.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sports,
                builder: (context, state) => const HomeDashboardScreen(),
                routes: [
                  GoRoute(
                    path: ':sport/setup',
                    name: AppRoutes.setupName,
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final sport =
                          AppRoutes.sportLabels[state.pathParameters['sport']];
                      return sport == null
                          ? const RouteErrorScreen(message: '지원하지 않는 운동 종목이에요.')
                          : SportSetupScreen(sport: sport);
                    },
                  ),
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
                path: AppRoutes.community,
                builder: (context, state) => const SportSelectScreen(),
                routes: [
                  GoRoute(
                    path: 'posts/:id',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final post = context
                          .watch<AppState>()
                          .members
                          .operations
                          .posts
                          .where((p) => p.id == state.pathParameters['id'])
                          .firstOrNull;
                      return post == null
                          ? const RouteErrorScreen(message: '모집글을 찾을 수 없어요.')
                          : RecruitmentDetailScreen(post: post);
                    },
                  ),
                  GoRoute(
                    path: ':sport',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final sport =
                          AppRoutes.sportLabels[state.pathParameters['sport']];
                      return sport == null
                          ? const RouteErrorScreen(message: '지원하지 않는 운동 종목이에요.')
                          : MatchScreen(sport: sport);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ranking,
                builder: (context, state) => const RankingScreen(),
              ),
            ],
          ),
          // 내정보 안에 기존 Plan/분석/AI 화면을 보존한다.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.me,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'weather',
                    builder: (context, state) => FeaturePage(
                      title: '실시간 운동 날씨',
                      child: LiveWeatherScreen(
                        key: ValueKey(app.loginId),
                        service: app.weatherService,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'plan',
                    builder: (context, state) => const FeaturePage(
                      title: '주간 계획 · DEMO',
                      child: PlanScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'analysis',
                    builder: (context, state) => const FeaturePage(
                      title: '운동 분석 · DEMO',
                      child: AnalysisScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'ai',
                    builder: (context, state) => FeaturePage(
                      title: 'AI 운동 도우미',
                      child: AiChatScreen(
                        key: ValueKey(app.loginId),
                        gateway: app.aiGateway,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
