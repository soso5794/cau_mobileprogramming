import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';
import 'member_widgets.dart';
import 'member_models.dart';

class MemberSettingsScreen extends StatelessWidget {
  const MemberSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.members.profile;
    if (p == null) return const SizedBox.shrink();
    return MemberPage(
      title: '설정',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('알림 설정'),
            subtitle: const Text('모집글 · 팀 소식 · 다가오는 일정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          SwitchListTile(
            title: const Text('다크 모드'),
            value: app.themeMode == ThemeMode.dark,
            onChanged: (_) => app.toggleTheme(),
          ),
          const Divider(height: 32),
          Text(p.nickname, style: Theme.of(context).textTheme.titleLarge),
          Text(p.email),
          const SizedBox(height: 16),
          const Text(
            '이 계정과 운동 프로필은 이 기기에만 저장됩니다. 서버 계정·메일·실제 푸시 알림은 연결되지 않았어요.',
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: app.members.busy ? null : app.logout,
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
          MemberError(app.members),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late MemberProfile draft;
  bool _dirty = false, _allowExit = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    draft = context.read<AppState>().members.profile!;
  }

  void change(MemberProfile p) => setState(() {
    draft = p;
    _dirty = true;
  });
  Future<void> exit() async {
    if (_confirming) return;
    _confirming = true;
    final discard = !_dirty || await confirmDiscard(context);
    if (!mounted) return;
    _confirming = false;
    if (discard) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.settings);
          }
        }
      });
    }
  }

  Future<void> pick(bool start) async {
    final m = start ? draft.quietStart : draft.quietEnd;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      cancelText: '취소',
      confirmText: '확인',
    );
    if (!mounted || result == null) return;
    final value = result.hour * 60 + result.minute;
    if (value == (start ? draft.quietEnd : draft.quietStart)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작·종료 시간을 다르게 선택해주세요.')));
      return;
    }
    change(
      start
          ? draft.copyWith(quietStart: value)
          : draft.copyWith(quietEnd: value),
    );
  }

  String time(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  Future<void> save() async {
    final vm = context.read<AppState>().members;
    if (await vm.save(draft) && mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림 선호를 기기에 저장했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    final enabled = draft.notifications['enabled']!;
    return PopScope<Object?>(
      canPop: (!_dirty && !vm.busy) || _allowExit,
      onPopInvokedWithResult: (p, r) {
        if (!p && !vm.busy) exit();
      },
      child: MemberPage(
        title: '알림 설정',
        onBack: () {
          if (!vm.busy) exit();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('선호 설정만 저장해요. 실제 알림 발송·기기 권한 요청은 하지 않아요.'),
            SwitchListTile(
              key: const Key('notification-master'),
              title: const Text('알림 받기'),
              value: enabled,
              onChanged: vm.busy
                  ? null
                  : (v) => change(
                      draft.copyWith(
                        notifications: {...draft.notifications, 'enabled': v},
                      ),
                    ),
            ),
            const Divider(),
            for (final entry in notificationLabels.entries)
              SwitchListTile(
                key: Key('notification-${entry.key}'),
                title: Text(entry.value),
                value: draft.notifications[entry.key]!,
                onChanged: !enabled || vm.busy
                    ? null
                    : (v) => change(
                        draft.copyWith(
                          notifications: {...draft.notifications, entry.key: v},
                        ),
                      ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: draft.reminder,
              isExpanded: true,
              decoration: memberInput('일정 알림 시점'),
              items: const [
                DropdownMenuItem(value: 1440, child: Text('하루 전')),
                DropdownMenuItem(value: 60, child: Text('1시간 전')),
                DropdownMenuItem(value: 30, child: Text('30분 전')),
              ],
              onChanged:
                  !enabled || !draft.notifications['schedule']! || vm.busy
                  ? null
                  : (v) => change(draft.copyWith(reminder: v)),
            ),
            SwitchListTile(
              title: const Text('방해금지 시간'),
              value: draft.quietEnabled,
              onChanged: !enabled || vm.busy
                  ? null
                  : (v) => change(draft.copyWith(quietEnabled: v)),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: enabled && draft.quietEnabled && !vm.busy
                      ? () => pick(true)
                      : null,
                  child: Text('시작 ${time(draft.quietStart)}'),
                ),
                OutlinedButton(
                  onPressed: enabled && draft.quietEnabled && !vm.busy
                      ? () => pick(false)
                      : null,
                  child: Text('종료 ${time(draft.quietEnd)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('종료가 시작보다 이르면 다음 날까지예요.'),
            MemberError(vm),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('notifications-save'),
              onPressed: _dirty && !vm.busy ? save : null,
              child: Text(vm.busy ? '저장 중…' : '설정 저장'),
            ),
          ],
        ),
      ),
    );
  }
}
