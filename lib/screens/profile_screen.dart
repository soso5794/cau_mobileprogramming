import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../members/member_widgets.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';
import '../calendar/workout_calendar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  Widget menu(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String path,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vm = app.members;
    final p = vm.profile;
    if (p == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nickname,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              p.isDemo ? 'DEMO · 가상 운동 메이트' : '로컬 프로토타입 계정',
                              style: TextStyle(color: scheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    p.common['bio']?.isNotEmpty == true
                        ? p.common['bio']!
                        : '자기소개를 작성하고 나를 알려주세요.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if ((p.common['region'] ?? '').isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.place_outlined, size: 18),
                          label: Text(p.common['region']!),
                        ),
                      for (final s in p.sports) Chip(label: Text(s)),
                    ],
                  ),
                  OutlinedButton.icon(
                    key: const Key('edit-profile'),
                    onPressed: () => context.push(AppRoutes.editProfile),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      p.onboarding == 'complete' ? '프로필 편집' : '운동 프로필 이어서 설정',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            WorkoutCalendar(key: ValueKey('calendar-${p.id}')),
            const SizedBox(height: 24),
            menu(
              context,
              Icons.smart_toy_outlined,
              'AI 운동 도우미',
              '운동 질문과 훈련 방법 상담',
              AppRoutes.aiPage,
            ),
            const SizedBox(height: 24),
            const MemberHeading('내 운동 프로필', '자가 평가와 경기 결과로 정해지는 티어는 구분돼요.'),
            if (p.sports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('아직 선택한 운동이 없어요. 프로필을 설정해보세요.'),
                ),
              ),
            for (final sport in p.sports)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(sportIcon(sport), color: sportColor(sport)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sport,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            key: Key('favorite-$sport'),
                            tooltip: p.favorites.contains(sport)
                                ? '즐겨찾기 해제'
                                : '즐겨찾기 추가',
                            onPressed: vm.busy
                                ? null
                                : () => vm.toggleFavorite(sport),
                            icon: Icon(
                              p.favorites.contains(sport)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        p.isDemo
                            ? 'DEMO 티어 · ${sport == '농구'
                                  ? 'SILVER II'
                                  : sport == '축구'
                                  ? 'BRONZE I'
                                  : '5km 러너'}'
                            : '티어 미배정 · 경기 기록이 쌓이면 산정 예정',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '자가 평가: ${p.answers[sport]?['skill'] ?? '미설정'} · ${p.answers[sport]?['frequency'] ?? '횟수 미설정'} · ${p.answers[sport]?['duration'] ?? '시간 미설정'}',
                      ),
                      if (sport == '런닝')
                        Text(
                          '페이스 ${p.answers[sport]?['pace'] ?? '미설정'} /km · ${p.answers[sport]?['distance'] ?? '거리 미설정'}',
                        ),
                      if (sport != '런닝')
                        Text(
                          '포지션 ${p.answers[sport]?['positions'] ?? '미설정'} · 선수 경험 ${p.answers[sport]?['playerBackground'] ?? '미응답'} (자기 신고)',
                        ),
                      TextButton(
                        onPressed: () => context.push(
                          '/sports/${AppRoutes.sportId(sport)}/setup',
                        ),
                        child: const Text('종목 프로필 수정'),
                      ),
                    ],
                  ),
                ),
              ),
            MemberError(vm),
            const SizedBox(height: 16),
            Text('즐겨찾는 운동', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (p.favorites.isEmpty) const Text('운동 카드의 별을 눌러 빠르게 열어보세요.'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in p.sports.where(p.favorites.contains))
                  ActionChip(
                    avatar: Icon(sportIcon(s), size: 18),
                    label: Text(s),
                    onPressed: () =>
                        context.push('/sports/${AppRoutes.sportId(s)}/setup'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('내 활동', style: Theme.of(context).textTheme.titleLarge),
            menu(
              context,
              Icons.groups_outlined,
              '내 팀·크루',
              p.isDemo ? '시연용 소속 팀 보기' : '소속 팀과 활동 정보',
              AppRoutes.teams,
            ),
            menu(
              context,
              Icons.pending_actions_outlined,
              '팀 가입신청 현황',
              '대기·승인·거절·취소 내역',
              AppRoutes.applications,
            ),
            menu(
              context,
              Icons.settings_outlined,
              '설정',
              '알림 · 화면 테마 · 계정',
              AppRoutes.settings,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('기존 운동 도구'),
              children: [
                ListTile(
                  title: const Text('주간 운동 계획'),
                  onTap: () => context.go(AppRoutes.planPage),
                ),
                ListTile(
                  title: const Text('운동 기록·분석'),
                  onTap: () => context.go(AppRoutes.analysisPage),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              key: const Key('logout'),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: vm.busy
                  ? null
                  : () async {
                      await vm.logout();
                    },
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
