import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../calendar/workout_event.dart';
import '../community/community_data.dart';
import '../community/recruitment_card.dart';
import '../models/app_state.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';

List<WorkoutEvent> upcomingEvents(List<WorkoutEvent> events, DateTime now) =>
    (events.where((e) => !e.completed && e.end.isAfter(now)).toList()
          ..sort((a, b) => a.start.compareTo(b.start)))
        .take(2)
        .toList();

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.members.profile;
    final scheme = Theme.of(context).colorScheme;
    final events = upcomingEvents(profile?.events ?? [], DateTime.now());
    final posts = recommendedRecruitments(
      app.selectedSports,
      profile?.favorites ?? {},
      source: app.members.operations.posts,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          key: const PageStorageKey('home-dashboard'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '${app.userName ?? ''}님, 반가워요',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              '오늘도 함께, 한 걸음.',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Material(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('home-community'),
                onTap: () => context.go(AppRoutes.community),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 36,
                        color: scheme.onPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '내 관심 종목 커뮤니티',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              app.selectedSports.isEmpty
                                  ? '함께할 운동을 골라보세요'
                                  : '관심 종목 ${app.selectedSports.length}개 · 함께할 메이트 찾기',
                              style: TextStyle(color: scheme.onPrimary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final ranking = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardHeading(
                      title: '이번 주 TOP 3',
                      action: '전체 랭킹',
                      onTap: () => context.go(AppRoutes.ranking),
                    ),
                    const RankingSpotlight(),
                  ],
                );
                final schedule = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardHeading(
                      title: '다가오는 일정',
                      action: '내 캘린더',
                      onTap: () => context.go(AppRoutes.me),
                    ),
                    if (events.isEmpty)
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              color: scheme.primary,
                              size: 30,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '다가오는 운동 일정이 없어요.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text('캘린더에 다음 운동을 계획해보세요.'),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('home-add-schedule'),
                              onPressed: () => context.go(AppRoutes.me),
                              child: const Text('일정 추가하러 가기'),
                            ),
                          ],
                        ),
                      ),
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ScheduleCard(event: event),
                      ),
                  ],
                );
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [ranking, const SizedBox(height: 24), schedule],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ranking),
                    const SizedBox(width: 24),
                    Expanded(child: schedule),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            DashboardHeading(
              title: '나에게 맞는 모집',
              action: '커뮤니티',
              onTap: () => context.go(AppRoutes.community),
            ),
            Text(
              '관심 종목 기준 · 즐겨찾는 운동 우선',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.selectedSports.isEmpty
                          ? '관심 종목을 고르면 모집글을 추천해요.'
                          : '선택한 종목의 추천 모집글이 아직 없어요.',
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.community),
                      child: const Text('커뮤니티 둘러보기'),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 2 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  children: [
                    for (final post in posts)
                      SizedBox(
                        width: width,
                        child: RecruitmentCard(post: post),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHeading extends StatelessWidget {
  const DashboardHeading({
    super.key,
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}

class RankingSpotlight extends StatefulWidget {
  const RankingSpotlight({super.key});
  @override
  State<RankingSpotlight> createState() => _RankingSpotlightState();
}

class _RankingSpotlightState extends State<RankingSpotlight> {
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          !_paused &&
          TickerMode.valuesOf(context).enabled &&
          !MediaQuery.disableAnimationsOf(context)) {
        final count = context
            .read<AppState>()
            .members
            .operations
            .rankings
            .length
            .clamp(0, 3);
        if (count > 0) setState(() => _index = (_index + 1) % count);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = context
        .watch<AppState>()
        .members
        .operations
        .sortedRankings
        .take(3)
        .toList();
    if (entries.isEmpty) {
      return const SectionCard(child: Text('아직 등록된 랭킹이 없어요.'));
    }
    final index = _index % entries.length;
    final entry = entries[index];
    final row = (entry.name, '이번 주 ${entry.count}회', '${index + 1}');
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                entry.isDemo ? '주간 활동 랭킹 · 예시' : '주간 활동 랭킹 · 운영자 입력',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              IconButton(
                tooltip: _paused ? '랭킹 자동 전환 재생' : '랭킹 자동 전환 일시정지',
                onPressed: () => setState(() => _paused = !_paused),
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
              ),
            ],
          ),
          InkWell(
            key: const Key('home-ranking'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(AppRoutes.ranking),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.tertiaryContainer,
                    child: Text(
                      '${row.$3}위',
                      style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(_index),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.$1,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(row.$2),
                        ],
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFFBA8B25),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < entries.length; i++)
                IconButton(
                  tooltip: '${i + 1}위 보기',
                  onPressed: () => setState(() => _index = i),
                  icon: Icon(
                    index == i ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String scheduleTime(WorkoutEvent event) =>
    '${event.start.month}/${event.start.day} · ${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')}';

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.event});
  final WorkoutEvent event;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: Key('home-event-${event.id}'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheetContext) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                '${event.sport} · ${scheduleTime(event)} · ${event.minutes}분',
              ),
              const SizedBox(height: 12),
              Text(event.place.isEmpty ? '장소 미정' : event.place),
              if (event.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(event.notes),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.go(AppRoutes.me);
                },
                child: const Text('캘린더에서 관리'),
              ),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scheduleTime(event),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${event.sport} · ${event.place.isEmpty ? '장소 미정' : event.place}',
            ),
          ],
        ),
      ),
    ),
  );
}
