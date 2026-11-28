import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/app_state.dart';
import 'workout_qr_session.dart';
import 'workout_tier.dart';
import '../ranking/ranking_data.dart';

class QrAttendanceScreen extends StatelessWidget {
  const QrAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR 운동 인증'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.qr_code_2_rounded), text: 'QR 발급'),
              Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'QR 스캔'),
              Tab(icon: Icon(Icons.history_rounded), text: '인증 내역'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _IssueQrTab(),
            _ScanQrTab(),
            _QrHistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _IssueQrTab extends StatefulWidget {
  const _IssueQrTab();

  @override
  State<_IssueQrTab> createState() => _IssueQrTabState();
}

class _IssueQrTabState extends State<_IssueQrTab> {
  WorkoutQrSession? _issued;
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.members.profile;
    if (profile == null) return const SizedBox.shrink();
    final previous = app.members.operations.workoutSessions
        .where((session) => session.hostId == profile.id)
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    final session = _issued ?? (previous.isEmpty ? null : previous.first);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(
          'QR 인증을 완료하면 나의 운동 티어 경험치가 올라가요.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '운동 주최자와 참가자 모두 인증 경험치를 받아요. 경기 승리나 러닝 거리에 따라 추가 경험치도 얻을 수 있어요.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _creating
              ? null
              : () async {
                  final draft = await showDialog<WorkoutQrSession>(
                    context: context,
                    builder: (_) => _CreateQrSessionDialog(
                      hostId: profile.id,
                      nickname: profile.nickname,
                      defaultPlace: profile.common['place'] ?? profile.common['region'] ?? '',
                    ),
                  );
                  if (draft == null || !mounted) return;
                  setState(() => _creating = true);
                  final success = await context.read<AppState>().members.createWorkoutQrSession(draft);
                  if (!mounted) return;
                  final updatedProfile = context.read<AppState>().members.profile;
                  final earnedXp = (updatedProfile?.tierExperiencePoints ?? profile.tierExperiencePoints) - profile.tierExperiencePoints;
                  final oldTier = WorkoutTier.forXp(profile.tierExperiencePoints);
                  final newTier = WorkoutTier.forXp(updatedProfile?.tierExperiencePoints ?? profile.tierExperiencePoints);
                  setState(() {
                    _creating = false;
                    if (success) _issued = draft.withAttendees([profile.id]);
                  });
                  if (success) {
                    final tierMessage = oldTier.name == newTier.name ? '' : ' · ${newTier.name} 티어 승급!';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('주최자 인증 완료 · +$earnedXp XP$tierMessage')));
                  } else {
                    final error = context.read<AppState>().members.error ?? 'QR을 발급하지 못했어요.';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
          icon: _creating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_circle_outline_rounded),
          label: Text(_creating ? 'QR 발급 중...' : '완료한 운동의 QR 발급'),
        ),
        const SizedBox(height: 16),
        if (session == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 54, color: scheme.outline),
                  const SizedBox(height: 10),
                  const Text('아직 발급한 운동 인증 QR이 없어요.'),
                  const SizedBox(height: 4),
                  Text('경기 결과를 입력하면 QR이 생성돼요.', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('${session.sport} · ${session.teamName}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${session.opponentName} · ${session.place}', style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: session.toQrPayload(),
                      version: QrVersions.auto,
                      size: 230,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(session.resultLabel, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('인증 시 기본 20 XP + 경기 결과·러닝 거리 보너스 · QR은 발급 후 48시간 유효', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SelectableText('인증 코드: ${session.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const _PrototypeNotice(),
      ],
    );
  }
}

class _CreateQrSessionDialog extends StatefulWidget {
  const _CreateQrSessionDialog({
    required this.hostId,
    required this.nickname,
    required this.defaultPlace,
  });
  final String hostId;
  final String nickname;
  final String defaultPlace;

  @override
  State<_CreateQrSessionDialog> createState() => _CreateQrSessionDialogState();
}

class _CreateQrSessionDialogState extends State<_CreateQrSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _team = TextEditingController(text: '${widget.nickname} 팀');
  final _opponent = TextEditingController(text: '상대 팀');
  late final _place = TextEditingController(text: widget.defaultPlace);
  final _teamScore = TextEditingController(text: '10');
  final _opponentScore = TextEditingController(text: '8');
  final _runningTime = TextEditingController(text: '00:30:00');
  String _sport = '농구';
  RunningDistance _distance = RunningDistance.five;
  String? _error;

  @override
  void dispose() {
    _team.dispose();
    _opponent.dispose();
    _place.dispose();
    _teamScore.dispose();
    _opponentScore.dispose();
    _runningTime.dispose();
    super.dispose();
  }

  int? _durationSeconds(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 3 || parts.any((part) => int.tryParse(part) == null)) return null;
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);
    if (hours > 23 || minutes > 59 || seconds > 59) return null;
    final total = hours * 3600 + minutes * 60 + seconds;
    return total > 0 && total <= 86399 ? total : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final random = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    final session = WorkoutQrSession(
      id: 'match-${now.microsecondsSinceEpoch}-$random',
      sport: _sport,
      teamName: _team.text.trim(),
      opponentName: _opponent.text.trim(),
      place: _place.text.trim(),
      hostId: widget.hostId,
      matchAt: now,
      issuedAt: now,
      teamScore: _sport == '런닝' ? null : int.tryParse(_teamScore.text.trim()),
      opponentScore: _sport == '런닝' ? null : int.tryParse(_opponentScore.text.trim()),
      distance: _sport == '런닝' ? _distance : null,
      seconds: _sport == '런닝' ? _durationSeconds(_runningTime.text) : null,
      attendeeIds: [widget.hostId],
    );
    final issue = session.validateForIssue(now: now);
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    Navigator.pop(context, session);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('운동 결과 입력'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _sport,
                  decoration: const InputDecoration(labelText: '운동 종목'),
                  items: const [
                    DropdownMenuItem(value: '농구', child: Text('농구')),
                    DropdownMenuItem(value: '축구', child: Text('축구')),
                    DropdownMenuItem(value: '런닝', child: Text('런닝')),
                  ],
                  onChanged: (value) => setState(() => _sport = value ?? '농구'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _team,
                  decoration: const InputDecoration(labelText: '내 팀 / 러닝 크루 이름'),
                  maxLength: 30,
                  validator: (value) => (value?.trim().length ?? 0) < 2 ? '2자 이상 입력해주세요.' : null,
                ),
                TextFormField(
                  controller: _opponent,
                  decoration: const InputDecoration(labelText: '상대 팀 / 활동 이름'),
                  maxLength: 30,
                  validator: (value) => (value?.trim().length ?? 0) < 2 ? '2자 이상 입력해주세요.' : null,
                ),
                TextFormField(
                  controller: _place,
                  decoration: const InputDecoration(labelText: '운동 장소'),
                  maxLength: 100,
                  validator: (value) => (value?.trim().isEmpty ?? true) ? '운동 장소를 입력해주세요.' : null,
                ),
                if (_sport != '런닝') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _teamScore,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '내 팀 점수'),
                          validator: (value) => _validScore(value),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text(':')),
                      Expanded(
                        child: TextFormField(
                          controller: _opponentScore,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '상대 점수'),
                          validator: (value) => _validScore(value),
                        ),
                      ),
                    ],
                  ),
                  if (_sport == '농구')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Align(alignment: Alignment.centerLeft, child: Text('경기 결과에 따라 티어 경험치 보너스가 달라져요.', style: TextStyle(fontSize: 11, color: Colors.grey))),
                    ),
                ] else ...[
                  DropdownButtonFormField<RunningDistance>(
                    value: _distance,
                    decoration: const InputDecoration(labelText: '러닝 거리'),
                    items: [
                      for (final distance in RunningDistance.values)
                        DropdownMenuItem(value: distance, child: Text(distance.label)),
                    ],
                    onChanged: (value) => setState(() => _distance = value ?? RunningDistance.five),
                  ),
                  TextFormField(
                    controller: _runningTime,
                    decoration: const InputDecoration(labelText: '완주 시간', hintText: 'HH:MM:SS'),
                    validator: (value) => _durationSeconds(value ?? '') == null ? '00:30:00 형식으로 입력해주세요.' : null,
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _submit, child: const Text('QR 발급')),
      ],
    );
  }

  String? _validScore(String? value) {
    final score = int.tryParse(value?.trim() ?? '');
    return score == null || score < 0 || score > 999 ? '0~999 사이의 점수를 입력해주세요.' : null;
  }
}

class _ScanQrTab extends StatefulWidget {
  const _ScanQrTab();

  @override
  State<_ScanQrTab> createState() => _ScanQrTabState();
}

class _ScanQrTabState extends State<_ScanQrTab> {
  bool _processing = false;
  String? _status;
  String? _lastHandledValue;

  Future<void> _handleRawValue(String raw) async {
    if (_processing || raw == _lastHandledValue) return;
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      final session = WorkoutQrSession.fromQrPayload(raw);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('운동 인증 확인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${session.sport} · ${session.teamName} vs ${session.opponentName}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('결과: ${session.resultLabel}'),
              Text('장소: ${session.place}'),
              Text('일시: ${session.matchAt.year}.${session.matchAt.month}.${session.matchAt.day}'),
              const SizedBox(height: 10),
              const Text('참가 사실과 경기 결과가 맞는지 확인한 뒤 인증해주세요.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('참가 인증')),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        final beforeProfile = context.read<AppState>().members.profile;
        final beforeXp = beforeProfile?.tierExperiencePoints ?? 0;
        final beforeTier = WorkoutTier.forXp(beforeXp);
        final success = await context.read<AppState>().members.confirmWorkoutQrSession(session);
        if (!mounted) return;
        final afterProfile = context.read<AppState>().members.profile;
        final afterXp = afterProfile?.tierExperiencePoints ?? beforeXp;
        final afterTier = WorkoutTier.forXp(afterXp);
        final earnedXp = afterXp - beforeXp;
        final tierUp = beforeTier.name == afterTier.name ? '' : ' · ${afterTier.name} 티어 승급!';
        final message = success
            ? '운동 인증 완료 · +$earnedXp XP$tierUp'
            : context.read<AppState>().members.error ?? '인증하지 못했어요.';
        setState(() {
          _status = message;
          _lastHandledValue = raw;
        });
      } else if (mounted) {
        setState(() {
          _status = '운동 인증을 취소했어요.';
          _lastHandledValue = raw;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _status = error.message;
          _lastHandledValue = raw;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'QR을 처리하지 못했어요. 다시 스캔해주세요.';
          _lastHandledValue = raw;
        });
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '카메라를 사용할 수 없어요. 앱의 카메라 권한을 허용한 뒤 다시 시도해주세요.\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                onDetect: (capture) {
                  if (capture.barcodes.isEmpty) return;
                  final raw = capture.barcodes.first.rawValue;
                  if (raw != null && raw.isNotEmpty) unawaited(_handleRawValue(raw));
                },
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
              if (_processing)
                const Center(child: Card(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            children: [
              const Text('운동 주최자가 발급한 QR 코드를 사각형 안에 맞춰주세요.'),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!, textAlign: TextAlign.center, style: TextStyle(color: _status!.contains('인증 완료') ? scheme.primary : scheme.error, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: _processing ? null : () => setState(() {
                    _status = null;
                    _lastHandledValue = null;
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('다시 스캔'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QrHistoryTab extends StatelessWidget {
  const _QrHistoryTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.members.profile;
    if (profile == null) return const SizedBox.shrink();
    final sessions = app.members.operations.workoutSessions
        .where((e) => e.hostId == profile.id || e.attendeeIds.contains(profile.id))
        .toList()
      ..sort((a, b) => b.matchAt.compareTo(a.matchAt));
    if (sessions.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('아직 QR로 인증한 운동이 없어요.')));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final host = session.hostId == profile.id;
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(session.sport == '런닝' ? Icons.directions_run_rounded : Icons.sports_basketball_rounded)),
            title: Text('${session.sport} · ${session.teamName}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${session.place}\n${session.resultLabel} · ${session.attendeeIds.length}명 인증 · +${WorkoutTier.xpForSession(session)} XP'),
            isThreeLine: true,
            trailing: Chip(label: Text(host ? '주최' : '참가')),
          ),
        );
      },
    );
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: const Text(
        'QR 인증과 티어 경험치는 현재 기기 로컬 저장 방식이에요. 다른 휴대폰과 인증 내역을 실시간 동기화하거나 QR 위변조를 검증하려면 공용 백엔드가 필요해요. QR 인증은 공개 랭킹을 변경하지 않고 본인의 티어 경험치만 올려요.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
