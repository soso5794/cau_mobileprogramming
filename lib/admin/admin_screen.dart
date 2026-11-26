import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../calendar/event_editor.dart';
import '../calendar/workout_event.dart';
import '../community/community_data.dart';
import '../members/member_models.dart';
import '../members/member_widgets.dart';
import '../models/app_state.dart';
import 'operations_data.dart';
import 'admin_editors.dart';
import '../ranking/ranking_admin.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int section = 0;
  String query = '';
  Future<bool> confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: const Text('이 기기의 저장된 데이터에서 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;
  void eventEditor(String owner, [WorkoutEvent? event]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        EventEditor(date: DateTime.now(), event: event, managedOwnerId: owner),
  );
  void rankEditor([RankingEntry? entry]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RankingEditor(entry: entry),
  );
  void postEditor([RecruitmentPreview? post]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecruitmentEditor(post: post),
  );
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    if (!vm.isOperator) {
      return const Scaffold(body: Center(child: Text('운영자 로그인이 필요합니다.')));
    }
    final people = vm.managedMembers
        .where(
          (p) => '${p.nickname} ${p.email}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return MemberPage(
      title: '운영 관리',
      onBack: () => context.go('/me'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MemberHeading('운영자 대시보드', '이 브라우저에 저장된 데이터를 관리합니다.'),
          Text(
            '회원 ${vm.managedMembers.length}명 · 일정 ${vm.managedMembers.fold<int>(0, (n, p) => n + p.events.length)}개 · 모집글 ${vm.operations.posts.length}개',
          ),
          const SizedBox(height: 12),
          const Text(
            '운영자 저장 작업은 서버 인증 후 반영됩니다. 랭킹은 수동 관리 데이터이며, 모집글 등록이 실제 참가 신청이나 예약을 생성하지는 않습니다.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 5; i++)
                ChoiceChip(
                  key: Key('admin-section-$i'),
                  label: Text(['회원정보', '일정', '랭킹', '모집글', '변경 이력'][i]),
                  selected: section == i,
                  onSelected: vm.busy
                      ? null
                      : (_) => setState(() => section = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          MemberError(vm),
          if (section < 2) ...[
            TextField(
              key: const Key('admin-search'),
              decoration: memberInput('닉네임·이메일 검색'),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 16),
            if (people.isEmpty) const Text('일치하는 회원이 없어요.'),
            for (final p in people)
              section == 0 ? _memberCard(p) : _eventsCard(p),
          ],
          if (section == 2) ...[
            FilledButton.tonalIcon(
              key: const Key('admin-sport-rankings'),
              onPressed: vm.busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => const SportRankingManager(),
                    ),
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('종목별 성적 관리'),
            ),
            const SizedBox(height: 16),
            const Text(
              '기존 주간 활동 랭킹',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('admin-add-ranking'),
              onPressed: vm.busy ? null : () => rankEditor(),
              icon: const Icon(Icons.add),
              label: const Text('랭킹 항목 추가'),
            ),
            const SizedBox(height: 12),
            const Text(
              '운동 횟수 내림차순으로 홈 주간 TOP 3에 반영돼요. 종목별 성적은 위 메뉴에서 관리합니다. 동률은 항목 ID 순으로 정렬합니다.',
            ),
            if (vm.operations.rankings.isEmpty) const Text('등록된 랭킹이 없어요.'),
            for (final entry in vm.operations.sortedRankings)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${entry.name} · ${entry.count}회${entry.isDemo ? ' · 예시' : ' · 운영자 입력'}',
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            key: Key('admin-rank-${entry.id}'),
                            onPressed: vm.busy ? null : () => rankEditor(entry),
                            child: const Text('수정'),
                          ),
                          TextButton(
                            onPressed: vm.busy
                                ? null
                                : () async {
                                    if (await confirm('랭킹 항목을 삭제할까요?')) {
                                      await vm.deleteRanking(entry.id);
                                    }
                                  },
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (section == 3) ...[
            FilledButton.icon(
              key: const Key('admin-add-post'),
              onPressed: vm.busy ? null : () => postEditor(),
              icon: const Icon(Icons.add),
              label: const Text('모집글 등록'),
            ),
            if (vm.operations.posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('등록된 모집글이 없어요.'),
              ),
            for (final post in vm.operations.posts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${post.sport} · ${post.title}'),
                      Text('${post.time} · ${post.place}'),
                      Wrap(
                        children: [
                          TextButton(
                            key: Key('admin-post-${post.id}'),
                            onPressed: vm.busy ? null : () => postEditor(post),
                            child: const Text('수정'),
                          ),
                          TextButton(
                            onPressed: vm.busy
                                ? null
                                : () async {
                                    if (await confirm('모집글을 삭제할까요?')) {
                                      await vm.deleteRecruitment(post.id);
                                    }
                                  },
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (section == 4) ...[
            const Text('최근 100건 · 이 기기에 저장된 변경 이력'),
            if (vm.operations.logs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('아직 관리 작업이 없어요.'),
              ),
            for (final log in vm.operations.logs)
              ListTile(
                title: Text(log.action),
                subtitle: Text(
                  '${log.target}\n${log.at.toLocal().toString().split('.').first}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _memberCard(MemberProfile p) {
    final vm = context.read<AppState>().members;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p.nickname,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(p.email),
            Text(p.isDemo ? 'DEMO 회원' : '일반/운영 회원'),
            Text(p.sports.isEmpty ? '관심 종목 미설정' : p.sports.join(' · ')),
            if ((p.common['bio'] ?? '').isNotEmpty) Text(p.common['bio']!),
            TextButton(
              key: Key('admin-profile-${p.id}'),
              onPressed: vm.busy
                  ? null
                  : () => context.push(
                      '/admin/member/${Uri.encodeComponent(p.id)}',
                    ),
              child: const Text('프로필·설문 수정'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventsCard(MemberProfile p) {
    final vm = context.read<AppState>().members;
    final events = [...p.events]..sort((a, b) => a.start.compareTo(b.start));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${p.nickname} · ${events.length}개 일정',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              key: Key('admin-event-add-${p.id}'),
              onPressed: vm.busy ? null : () => eventEditor(p.id),
              icon: const Icon(Icons.add),
              label: const Text('일정 추가'),
            ),
            for (final e in events) ...[
              const Divider(),
              Text(e.title),
              Text(
                '${e.start.toString().substring(0, 16)} · ${e.sport} · ${e.minutes}분',
              ),
              Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    label: Text(e.completed ? '완료' : '예정'),
                    selected: e.completed,
                    onSelected: vm.busy
                        ? null
                        : (v) => vm.saveManagedEvent(p.id, e.withCompleted(v)),
                  ),
                  TextButton(
                    onPressed: vm.busy ? null : () => eventEditor(p.id, e),
                    child: const Text('수정'),
                  ),
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () async {
                            if (await confirm('일정을 삭제할까요?')) {
                              await vm.deleteManagedEvent(p.id, e.id);
                            }
                          },
                    child: const Text('삭제'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
