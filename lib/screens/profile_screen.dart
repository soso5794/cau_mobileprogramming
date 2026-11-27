import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../calendar/workout_calendar.dart';
import '../calendar/workout_event.dart';
import '../members/member_controller.dart';
import '../members/member_models.dart';
import '../members/member_widgets.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';

/// 내정보 탭. 프로필 → 참여/완료 → 내 운동 프로필 → 이번 주 운동 →
/// 캘린더 → 내 활동 → 나만 보는 설정 순서로 보여준다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedSport;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _answer(MemberProfile p, String sport, String key, String empty) {
    final v = p.answers[sport]?[key];
    return v == null || v.isEmpty ? empty : v;
  }

  /// 아직 내 운동에 없는 종목을 고르면, 그 종목의 추가 정보 입력 화면으로 보낸다.
  Future<void> _addSport(MemberProfile p) async {
    final remaining = memberSports.where((s) => !p.sports.contains(s)).toList();
    if (remaining.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '추가할 운동을 선택하세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('선택하면 그 운동의 실력·횟수 같은 추가 정보를 입력해요.'),
            ),
            for (final s in remaining)
              ListTile(
                key: Key('add-sport-$s'),
                leading: Icon(sportIcon(s), color: sportColor(s)),
                title: Text(s),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(c, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      context.push(AppRoutes.setupPath(picked, isNew: true));
    }
  }

  int _weeklyGoal(MemberProfile p) {
    var total = 0;
    for (final s in p.sports) {
      final m = RegExp(r'\d+').firstMatch(p.answers[s]?['frequency'] ?? '');
      if (m != null) total += int.parse(m.group(0)!);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vm = app.members;
    final p = vm.profile;
    if (p == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    final sport = p.sports.contains(_selectedSport)
        ? _selectedSport
        : (p.sports.isEmpty
              ? null
              : (p.sports.firstWhere(
                  p.favorites.contains,
                  orElse: () => p.sports.first,
                )));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _header(context, p, vm.isOperator, scheme),
            const SizedBox(height: 12),
            _stats(p, scheme),
            const SizedBox(height: 24),
            const _Heading('내 운동 프로필'),
            _sportProfile(context, p, sport, vm, scheme),
            const SizedBox(height: 16),
            _weekSummary(context, p, scheme),
            const SizedBox(height: 16),
            WorkoutCalendar(key: ValueKey('calendar-${p.id}')),
            MemberError(vm),
            const SizedBox(height: 24),
            const _Heading('내 활동'),
            _MenuGroup(
              items: [
                _MenuItem(
                  Icons.groups_outlined,
                  '내 팀·크루',
                  p.isDemo ? '시연용 소속 팀 보기' : '소속 팀과 활동 정보',
                  () => context.push(AppRoutes.teams),
                ),
                _MenuItem(
                  Icons.pending_actions_outlined,
                  '팀 가입신청 현황',
                  '대기·승인·거절·취소 내역',
                  () => context.push(AppRoutes.applications),
                ),
                _MenuItem(
                  Icons.event_note_outlined,
                  '주간 운동 계획',
                  '이번 주 운동 계획 세우기',
                  () => context.go(AppRoutes.planPage),
                ),
                _MenuItem(
                  Icons.monitor_heart_outlined,
                  '운동 기록·분석',
                  '운동 기록과 분석 보기',
                  () => context.go(AppRoutes.analysisPage),
                ),
                _MenuItem(
                  Icons.cloud_outlined,
                  '실시간 운동 날씨',
                  '장소별 현재 날씨·24시간 예보·종목별 환경지수',
                  () => context.push(AppRoutes.weatherPage),
                ),
                _MenuItem(
                  Icons.smart_toy_outlined,
                  'AI 운동 도우미',
                  '운동 질문과 훈련 방법 상담',
                  () => context.push(AppRoutes.aiPage),
                ),
                if (vm.isOperator)
                  _MenuItem(
                    Icons.admin_panel_settings_outlined,
                    '운영 관리',
                    '회원정보 · 일정 · 랭킹 · 모집글',
                    () => context.push(AppRoutes.admin),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const _Heading('나만 보는 설정'),
            _MenuGroup(
              items: [
                _MenuItem(
                  Icons.place_outlined,
                  '시간·장소 선호',
                  [
                    p.common['times'],
                    p.common['region'],
                  ].where((e) => e != null && e.isNotEmpty).join(' · ').isEmpty
                      ? '선호 시간대와 지역을 설정해보세요'
                      : [
                          p.common['times'],
                          p.common['region'],
                        ].where((e) => e != null && e.isNotEmpty).join(' · '),
                  () => context.push(AppRoutes.editProfile),
                ),
                _MenuItem(
                  Icons.person_outline,
                  '기본 정보·공개 범위',
                  '알림 · 화면 테마 · 계정',
                  () => context.push(AppRoutes.settings),
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

  // ───────────── 프로필 헤더 ─────────────
  Widget _header(
    BuildContext context,
    MemberProfile p,
    bool isOperator,
    ColorScheme scheme,
  ) {
    final bio = p.common['bio'];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 40,
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
                    const SizedBox(height: 2),
                    Text(
                      isOperator
                          ? '운영자 · 관리 권한'
                          : p.isDemo
                          ? 'DEMO · 가상 운동 메이트'
                          : '로컬 프로토타입 계정',
                      style: TextStyle(color: scheme.primary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in p.sports)
                          _SportPill(sport: s),
                        if (p.sports.isEmpty)
                          const Text(
                            '운동을 선택해주세요',
                            style: TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            bio != null && bio.isNotEmpty ? bio : '자기소개를 작성하고 나를 알려주세요.',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('edit-profile'),
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              p.onboarding == 'complete' ? '프로필 편집' : '운동 프로필 이어서 설정',
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── 참여 / 완료 ─────────────
  Widget _stats(MemberProfile p, ColorScheme scheme) {
    final joined = p.events.length;
    final done = p.events.where((e) => e.completed).length;
    Widget cell(String label, int n) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Text(
              '$n회',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : Colors.white,
      ),
      child: Row(
        children: [
          cell('참여', joined),
          Container(width: 1, height: 24, color: scheme.outlineVariant),
          cell('완료', done),
        ],
      ),
    );
  }

  // ───────────── 내 운동 프로필 (종목 토글 + 요약) ─────────────
  Widget _sportProfile(
    BuildContext context,
    MemberProfile p,
    String? sport,
    MemberController vm,
    ColorScheme scheme,
  ) {
    if (sport == null) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('아직 선택한 운동이 없어요. 프로필을 설정해보세요.'),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('add-sport'),
              onPressed: () => _addSport(p),
              icon: const Icon(Icons.add),
              label: const Text('운동 추가하기'),
            ),
          ],
        ),
      );
    }
    final color = sportColor(sport);
    final tier = p.isDemo
        ? 'DEMO 티어 · ${sport == '농구'
              ? 'SILVER II'
              : sport == '축구'
              ? 'BRONZE I'
              : '5km 러너'}'
        : '티어 미배정 · 경기 기록이 쌓이면 산정 예정';
    final skill = _answer(p, sport, 'skill', '미설정');
    final isRunning = sport == '런닝';
    final detail = isRunning
        ? '페이스 ${_answer(p, sport, 'pace', '미설정')} /km · ${_answer(p, sport, 'distance', '거리 미설정')}'
        : '포지션 ${_answer(p, sport, 'positions', '미설정')} · 선수 경험 ${_answer(p, sport, 'playerBackground', '미응답')} (자기 신고)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final s in p.sports)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s == p.sports.last ? 0 : 8),
                  child: _SportToggle(
                    key: Key('sport-toggle-$s'),
                    sport: s,
                    selected: s == sport,
                    onTap: () => setState(() => _selectedSport = s),
                  ),
                ),
              ),
            if (memberSports.any((s) => !p.sports.contains(s)))
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: '운동 추가',
                  child: InkWell(
                    key: const Key('add-sport'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _addSport(p),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.add, color: scheme.primary),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withAlpha(110),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(sportIcon(sport), color: color, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_answer(p, sport, 'frequency', '횟수 미설정')} · '
                      '1회 ${_answer(p, sport, 'duration', '시간 미설정')}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('favorite-$sport'),
                    tooltip: p.favorites.contains(sport)
                        ? '즐겨찾기 해제'
                        : '즐겨찾기 추가',
                    onPressed: vm.busy ? null : () => vm.toggleFavorite(sport),
                    icon: Icon(
                      p.favorites.contains(sport)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.bar_chart_rounded,
                text: '현재 실력: $skill · 자기평가',
              ),
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.emoji_events_outlined, text: tier),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.push('/sports/${AppRoutes.sportId(sport)}/setup'),
                  child: const Text('종목 프로필 수정'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────── 추가 기능: 이번 주 운동 + 다음 일정 ─────────────
  Widget _weekSummary(
    BuildContext context,
    MemberProfile p,
    ColorScheme scheme,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final week = p.events
        .where((e) => !e.start.isBefore(weekStart) && e.start.isBefore(weekEnd))
        .toList();
    final done = week.where((e) => e.completed).toList();
    final minutes = done.fold<int>(0, (sum, e) => sum + e.minutes);
    final goal = _weeklyGoal(p) > 0 ? _weeklyGoal(p) : week.length;
    final progress = goal == 0 ? 0.0 : (done.length / goal).clamp(0.0, 1.0);

    final upcoming = p.events.where((e) => !e.completed && e.end.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final next = upcoming.isEmpty ? null : upcoming.first;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(icon: Icons.local_fire_department_outlined, text: '이번 주 운동'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal == 0
                      ? '이번 주 일정이 아직 없어요'
                      : '${done.length} / $goal회 완료 · 총 $minutes분',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (goal > 0 && done.length >= goal)
                Icon(Icons.check_circle, color: scheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: const Key('weekly-progress'),
              value: progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            goal == 0
                ? '캘린더에 운동 일정을 추가해보세요.'
                : '목표는 종목 프로필의 주간 운동 횟수 기준이에요.',
            style: const TextStyle(fontSize: 12),
          ),
          const Divider(height: 24),
          if (next == null)
            const Row(
              children: [
                Icon(Icons.event_available_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('예정된 운동이 없어요. 아래 캘린더에서 추가해보세요.')),
              ],
            )
          else
            _nextEvent(next, today, scheme),
        ],
      ),
    );
  }

  Widget _nextEvent(WorkoutEvent e, DateTime today, ColorScheme scheme) {
    final day = DateTime(e.start.year, e.start.month, e.start.day);
    final diff = day.difference(today).inDays;
    final dday = diff <= 0 ? '오늘' : 'D-$diff';
    return Row(
      key: const Key('next-event'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            dday,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('다음 일정', style: TextStyle(fontSize: 12)),
              Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${e.start.month}월 ${e.start.day}일 (${_weekdays[e.start.weekday - 1]}) '
                '${_clock(e.start)} · ${e.minutes}분 · ${e.sport}'
                '${e.place.isEmpty ? '' : ' · ${e.place}'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────── 작은 위젯들 ─────────────
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _SportPill extends StatelessWidget {
  const _SportPill({required this.sport});
  final String sport;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(sportIcon(sport), size: 16, color: sportColor(sport)),
        const SizedBox(width: 4),
        Text(sport, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}

class _SportToggle extends StatelessWidget {
  const _SportToggle({
    super.key,
    required this.sport,
    required this.selected,
    required this.onTap,
  });
  final String sport;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: sport,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : null,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                sportIcon(sport),
                size: 18,
                color: selected ? scheme.onPrimary : sportColor(sport),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  sport,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? scheme.onPrimary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ],
  );
}

class _MenuItem {
  const _MenuItem(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItem> items;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHigh : Colors.white,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            ListTile(
              leading: Icon(items[i].icon, color: scheme.primary),
              title: Text(items[i].title),
              subtitle: Text(items[i].subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}
