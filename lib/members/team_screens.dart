import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import 'member_widgets.dart';

class MemberTeamsScreen extends StatelessWidget {
  const MemberTeamsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().members.profile;
    if (p == null) return const SizedBox.shrink();
    return MemberPage(
      title: '내 팀·크루',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemberHeading(
            p.isDemo ? 'DEMO · 내 팀' : '함께할 팀을 만나보세요',
            p.isDemo
                ? '실제 가입이나 팀 활동을 뜻하지 않는 시연 데이터예요.'
                : '아직 소속된 팀이 없어요. 팀 기능 연동 후 여기에 표시돼요.',
          ),
          if (p.isDemo)
            for (final sport in p.sports)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$sport ${sport == '런닝' ? '모닝 크루' : '캠퍼스 팀'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text('DEMO · 멤버 · 가입 2026.11.01'),
                      const SizedBox(height: 12),
                      Text('${p.common['region'] ?? '서울'} · 정기 활동 주 1회'),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('$sport 팀 소개'),
                            content: const Text(
                              '초보자도 함께 즐기는 시연용 팀입니다. 실제 팀 관리·채팅·모집은 커뮤니티 담당 기능과 연동할 예정이에요.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('닫기'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('팀 정보 보기'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  String _filter = '전체';
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    final p = vm.profile;
    if (p == null) return const SizedBox.shrink();
    final rows = p.isDemo
        ? [
            (
              id: 'pending',
              name: '주말 운동 메이트',
              status: p.cancelledApplications.contains('pending') ? '취소' : '대기',
            ),
            (id: 'approved', name: '캠퍼스 스포츠', status: '승인'),
            (id: 'rejected', name: '지역 교류 크루', status: '거절'),
          ]
        : <({String id, String name, String status})>[];
    final visible = rows
        .where((r) => _filter == '전체' || r.status == _filter)
        .toList();
    return MemberPage(
      title: '팀 가입신청 현황',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.isDemo) const Text('DEMO · 신청 상태와 취소는 이 기기에서만 시연돼요.'),
          ChoiceGroup(
            label: '신청 상태',
            options: const ['전체', '대기', '승인', '거절', '취소'],
            selected: {_filter},
            onSelected: (v) => setState(() => _filter = v),
          ),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('해당하는 가입신청이 없어요.'),
              ),
            ),
          for (final r in visible)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(r.name, style: Theme.of(context).textTheme.titleLarge),
                    Text('상태: ${r.status}'),
                    if (r.status == '대기')
                      OutlinedButton(
                        key: const Key('cancel-application'),
                        onPressed: vm.busy
                            ? null
                            : () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('가입신청을 취소할까요?'),
                                    content: const Text(
                                      'DEMO 신청 내역을 취소 상태로 바꿔요.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('돌아가기'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('신청 취소'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true && mounted) {
                                  await vm.cancelApplication(r.id);
                                }
                              },
                        child: const Text('가입신청 취소'),
                      ),
                  ],
                ),
              ),
            ),
          MemberError(vm),
        ],
      ),
    );
  }
}
