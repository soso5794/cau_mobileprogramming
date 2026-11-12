import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/notification_preferences.dart';
import '../routing/app_routes.dart';

/// 화면 초안은 setState, 저장된 설정은 AppState로 관리하는 예제.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final String _userId;
  late NotificationPreferences _saved;
  late NotificationPreferences _draft;
  bool _allowExit = false;
  bool _confirmingExit = false;

  bool get _dirty => _draft != _saved;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _userId = app.loginId!; // 라우터가 로그인한 사용자만 허용한다.
    _saved = app.notificationPreferences;
    _draft = _saved;
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.sports); // 직접 링크로 연 경우
    }
  }

  Future<void> _requestExit() async {
    if (_confirmingExit) return;
    if (!_dirty) {
      _leave();
      return;
    }
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항을 버릴까요?'),
        content: const Text('저장하지 않은 알림 설정은 반영되지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 수정'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('변경 버리기'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _confirmingExit = false;
    if (discard != true) return;
    setState(() => _allowExit = true);
    // PopScope가 새 canPop 값을 반영한 다음에 이동한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leave();
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _draft.quietStartMinutes : _draft.quietEndMinutes;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: start ? '방해금지 시작 시간' : '방해금지 종료 시간',
    );
    if (!mounted || result == null) return;
    final selected = result.hour * 60 + result.minute;
    final other = start ? _draft.quietEndMinutes : _draft.quietStartMinutes;
    if (selected == other) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작과 종료 시간을 다르게 설정해주세요.')));
      return;
    }
    setState(() {
      _draft = start
          ? _draft.copyWith(quietStartMinutes: selected)
          : _draft.copyWith(quietEndMinutes: selected);
    });
  }

  void _save() {
    final saved = context.read<AppState>().saveNotificationPreferences(
      _userId,
      _draft,
    );
    if (!saved) return;
    setState(() => _saved = _draft);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('알림 설정을 저장했어요. (현재 실행 중에만 유지)')),
    );
  }

  String _timeLabel(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final remindersEnabled =
        _draft.enabled && _draft.topics.contains(NotificationTopic.schedule);
    return PopScope<Object?>(
      canPop: !_dirty || _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('알림 설정'),
          leading: IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back),
            onPressed: _requestExit,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('설정 시연 화면입니다. 실제 푸시 알림이나 기기 권한을 사용하지 않아요.'),
              ),
            ),
            SwitchListTile(
              key: const Key('notifications-enabled'),
              title: const Text('푸시 알림 받기'),
              subtitle: Text(_dirty ? '저장하지 않은 변경이 있어요' : '저장된 설정과 같아요'),
              value: _draft.enabled,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(enabled: value)),
            ),
            const Divider(),
            const Text('알림 종류', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final topic in NotificationTopic.values)
              SwitchListTile(
                key: Key('topic-${topic.name}'),
                title: Text(topic.label),
                subtitle: Text(topic.description),
                value: _draft.topics.contains(topic),
                onChanged: !_draft.enabled
                    ? null
                    : (enabled) {
                        final next = {..._draft.topics};
                        enabled ? next.add(topic) : next.remove(topic);
                        setState(() => _draft = _draft.copyWith(topics: next));
                      },
              ),
            const Divider(),
            const Text(
              '운동 시작 전',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('참가 확정된 모임에 사용할 선호 시점이에요.'),
            for (final entry in const {
              1440: '하루 전',
              60: '1시간 전',
              30: '30분 전',
              0: '시작할 때',
            }.entries)
              CheckboxListTile(
                key: Key('reminder-${entry.key}'),
                title: Text(entry.value),
                value: _draft.reminderMinutes.contains(entry.key),
                onChanged: !remindersEnabled
                    ? null
                    : (checked) {
                        final next = {..._draft.reminderMinutes};
                        checked == true
                            ? next.add(entry.key)
                            : next.remove(entry.key);
                        setState(
                          () => _draft = _draft.copyWith(reminderMinutes: next),
                        );
                      },
              ),
            if (_draft.reminderMinutes.isEmpty)
              const Text('시작 전 알림 시점을 선택하지 않았어요.'),
            const Divider(),
            SwitchListTile(
              key: const Key('quiet-enabled'),
              title: const Text('방해금지 시간'),
              value: _draft.quietEnabled,
              onChanged: !_draft.enabled
                  ? null
                  : (value) => setState(
                      () => _draft = _draft.copyWith(quietEnabled: value),
                    ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('quiet-start'),
                  onPressed: _draft.enabled && _draft.quietEnabled
                      ? () => _pickTime(start: true)
                      : null,
                  child: Text('시작 ${_timeLabel(_draft.quietStartMinutes)}'),
                ),
                OutlinedButton(
                  key: const Key('quiet-end'),
                  onPressed: _draft.enabled && _draft.quietEnabled
                      ? () => _pickTime(start: false)
                      : null,
                  child: Text('종료 ${_timeLabel(_draft.quietEndMinutes)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('종료 시간이 시작보다 이르면 다음 날까지로 설정돼요. 실제 알림 발송은 구현하지 않았어요.'),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('save-notifications'),
            onPressed: _dirty ? _save : null,
            child: const Text('설정 저장'),
          ),
        ),
      ),
    );
  }
}
