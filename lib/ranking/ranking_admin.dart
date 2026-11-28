import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin/admin_gateway.dart';

import '../members/member_models.dart';
import '../members/member_repository.dart';
import '../models/app_state.dart';
import 'ranking_data.dart';

class SportRankingManager extends StatefulWidget {
  const SportRankingManager({super.key});
  @override
  State<SportRankingManager> createState() => _SportRankingManagerState();
}

class _SportRankingManagerState extends State<SportRankingManager> {
  RankingSport sport = RankingSport.basketball;
  RunningDistance distance = RunningDistance.five;
  String? error;
  Future<void> edit([SportRankingEntry? entry]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SportRankingEditor(
      entry: entry,
      initialSport: sport,
      initialDistance: distance,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    final entries = vm.operations.sportRankings
        .where(
          (e) =>
              e.sport == sport &&
              (sport != RankingSport.running || e.distance == distance),
        )
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 640,
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '종목별 성적 관리',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CloseButton(
                    onPressed: vm.busy ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('sport-rank-list'),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    '팀 누적 성적과 개인 완주 기록을 등록합니다. 계정을 연결하면 해당 회원의 내 순위에 표시돼요.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final value in RankingSport.values)
                        ChoiceChip(
                          key: Key('manage-sport-${value.name}'),
                          label: Text(value.label),
                          selected: sport == value,
                          onSelected: vm.busy
                              ? null
                              : (_) => setState(() {
                                  sport = value;
                                  error = null;
                                }),
                        ),
                    ],
                  ),
                  if (sport == RankingSport.running)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final value in RunningDistance.values)
                          ChoiceChip(
                            key: Key('manage-distance-${value.name}'),
                            label: Text(value.label),
                            selected: distance == value,
                            onSelected: vm.busy
                                ? null
                                : (_) => setState(() => distance = value),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('sport-rank-add'),
                    onPressed: vm.busy ? null : () => edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('성적 등록'),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty) const Text('등록된 성적이 없어요.'),
                  for (final entry in entries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              entry.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('${entry.valueLabel} · ${entry.detailLabel}'),
                            Text(entry.isDemo ? '예시 데이터' : '운영자 입력'),
                            Wrap(
                              children: [
                                TextButton(
                                  key: Key('sport-rank-edit-${entry.id}'),
                                  onPressed: vm.busy ? null : () => edit(entry),
                                  child: const Text('수정'),
                                ),
                                TextButton(
                                  key: Key('sport-rank-delete-${entry.id}'),
                                  onPressed: vm.busy
                                      ? null
                                      : () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              title: const Text('성적을 삭제할까요?'),
                                              content: Text(
                                                '${entry.name}의 기록을 삭제하고 순위를 다시 계산합니다.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, false),
                                                  child: const Text('취소'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, true),
                                                  child: const Text('삭제'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true || !mounted) {
                                            return;
                                          }
                                          final ok = await vm
                                              .deleteSportRanking(entry.id);
                                          if (mounted) {
                                            setState(
                                              () =>
                                                  error = ok ? null : vm.error,
                                            );
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SportRankingEditor extends StatefulWidget {
  const SportRankingEditor({
    super.key,
    this.entry,
    required this.initialSport,
    required this.initialDistance,
  });
  final SportRankingEntry? entry;
  final RankingSport initialSport;
  final RunningDistance initialDistance;
  @override
  State<SportRankingEditor> createState() => _SportRankingEditorState();
}

class _SportRankingEditorState extends State<SportRankingEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.entry?.name ?? '');
  late final fields = <String, TextEditingController>{
    'wins': TextEditingController(text: '${widget.entry?.wins ?? 0}'),
    'draws': TextEditingController(text: '${widget.entry?.draws ?? 0}'),
    'losses': TextEditingController(text: '${widget.entry?.losses ?? 0}'),
    'goalsFor': TextEditingController(text: '${widget.entry?.goalsFor ?? 0}'),
    'goalsAgainst': TextEditingController(
      text: '${widget.entry?.goalsAgainst ?? 0}',
    ),
    'time': TextEditingController(text: _editTime(widget.entry?.seconds ?? 0)),
    'date': TextEditingController(
      text: _editDate(widget.entry?.achievedAt ?? DateTime.now()),
    ),
  };
  late RankingSport sport = widget.entry?.sport ?? widget.initialSport;
  late RunningDistance distance =
      widget.entry?.distance ?? widget.initialDistance;
  late String ownerId = widget.entry?.ownerId ?? '';
  late final memberIds = {...?widget.entry?.memberIds};
  late bool isDemo = widget.entry?.isDemo ?? false;
  bool saving = false;
  String? error;

  static String _editTime(int seconds) =>
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  static String _editDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTime? _date(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null && _editDate(date) == value ? date : null;
  }

  @override
  void dispose() {
    name.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  SportRankingEntry _entry() => SportRankingEntry(
    id:
        widget.entry?.id ??
        'sport-rank-${DateTime.now().microsecondsSinceEpoch}',
    sport: sport,
    name: name.text.trim(),
    isDemo: isDemo,
    ownerId: sport == RankingSport.running && ownerId.isNotEmpty
        ? ownerId
        : null,
    memberIds: sport == RankingSport.running ? [] : memberIds.toList(),
    wins: sport == RankingSport.running
        ? 0
        : int.tryParse(fields['wins']!.text) ?? 0,
    losses: sport == RankingSport.running
        ? 0
        : int.tryParse(fields['losses']!.text) ?? 0,
    draws: sport == RankingSport.soccer
        ? int.tryParse(fields['draws']!.text) ?? 0
        : 0,
    goalsFor: sport == RankingSport.soccer
        ? int.tryParse(fields['goalsFor']!.text) ?? 0
        : 0,
    goalsAgainst: sport == RankingSport.soccer
        ? int.tryParse(fields['goalsAgainst']!.text) ?? 0
        : 0,
    distance: sport == RankingSport.running ? distance : null,
    seconds: sport == RankingSport.running
        ? parseRunningTime(fields['time']!.text)
        : null,
    achievedAt: sport == RankingSport.running
        ? _date(fields['date']!.text.trim())
        : null,
  );

  Widget number(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: Key('sport-rank-$key'),
      controller: fields[key],
      enabled: !saving,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      maxLength: 4,
      validator: (v) => MemberValidation.number(v, 0, 9999, required: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    final people = <String, MemberProfile>{
      for (final p in MemberRepository.demoProfiles) p.id: p,
      for (final p in vm.managedMembers.where((p) => p.id != operatorId))
        p.id: p,
    };
    final running = sport == RankingSport.running;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.entry == null ? '종목별 성적 등록' : '종목별 성적 수정'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<RankingSport>(
                    key: const Key('sport-rank-sport'),
                    initialValue: sport,
                    decoration: const InputDecoration(labelText: '종목'),
                    isExpanded: true,
                    items: [
                      for (final value in RankingSport.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: saving || widget.entry != null
                        ? null
                        : (v) => setState(() => sport = v!),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('sport-rank-name'),
                    controller: name,
                    enabled: !saving,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: running ? '러너 표시 이름' : '팀 이름',
                    ),
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ||
                            (v?.trim().length ?? 0) > 30
                        ? '이름은 2~30자로 입력해주세요.'
                        : null,
                  ),
                  if (running) ...[
                    DropdownButtonFormField<RunningDistance>(
                      key: const Key('sport-rank-distance'),
                      initialValue: distance,
                      decoration: const InputDecoration(labelText: '거리'),
                      isExpanded: true,
                      items: [
                        for (final value in RunningDistance.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              '${value.label} · ${value.description}',
                            ),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) => setState(() => distance = v!),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('sport-rank-time'),
                      controller: fields['time'],
                      enabled: !saving,
                      maxLength: 8,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: '완주 시간 (시:분:초)',
                        hintText: '00:18:32',
                      ),
                      validator: (v) => parseRunningTime(v ?? '') == null
                          ? '00:00:01~23:59:59로 입력해주세요.'
                          : null,
                    ),
                    TextFormField(
                      key: const Key('sport-rank-date'),
                      controller: fields['date'],
                      enabled: !saving,
                      maxLength: 10,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: '달성일 (YYYY-MM-DD)',
                      ),
                      validator: (v) {
                        final date = _date(v?.trim() ?? '');
                        final today = DateTime.now();
                        return date == null ||
                                date.year < 2000 ||
                                !date.isBefore(
                                  DateTime(
                                    today.year,
                                    today.month,
                                    today.day + 1,
                                  ),
                                )
                            ? '2000년부터 오늘까지의 올바른 날짜를 입력해주세요.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: const Key('sport-rank-owner'),
                      initialValue: ownerId,
                      decoration: const InputDecoration(labelText: '러너 계정 연결'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('계정 연결 안 함'),
                        ),
                        if (ownerId.isNotEmpty && !people.containsKey(ownerId))
                          DropdownMenuItem(
                            value: ownerId,
                            child: const Text('기존 연결 계정'),
                          ),
                        for (final p in people.values)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.nickname}${p.isDemo ? ' (DEMO)' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) => setState(() => ownerId = v ?? ''),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '계정을 연결하면 거리별 최고 기록 1개로 집계해요. 연결하지 않은 항목은 각각 별도 러너로 표시됩니다.',
                    ),
                  ] else ...[
                    number('wins', '승'),
                    if (sport == RankingSport.soccer) number('draws', '무'),
                    number('losses', '패'),
                    if (sport == RankingSport.soccer) ...[
                      number('goalsFor', '득점'),
                      number('goalsAgainst', '실점'),
                    ],
                    const Text('내 팀 순위를 표시할 회원 계정'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in people.values)
                          FilterChip(
                            key: Key('sport-rank-member-${p.id}'),
                            label: Text(
                              '${p.nickname}${p.isDemo ? ' (DEMO)' : ''}',
                            ),
                            selected: memberIds.contains(p.id),
                            onSelected: saving
                                ? null
                                : (v) => setState(() {
                                    if (v) {
                                      memberIds.add(p.id);
                                    } else {
                                      memberIds.remove(p.id);
                                    }
                                  }),
                          ),
                        for (final id in memberIds.where(
                          (id) => !people.containsKey(id),
                        ))
                          InputChip(
                            label: const Text('기존 연결 계정'),
                            onDeleted: saving
                                ? null
                                : () => setState(() => memberIds.remove(id)),
                          ),
                      ],
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('예시 데이터'),
                    value: isDemo,
                    onChanged: saving
                        ? null
                        : (v) => setState(() => isDemo = v),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      key: const Key('sport-rank-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('sport-rank-save'),
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final entry = _entry();
                    final problem = entry.validate();
                    if (problem != null) {
                      setState(() => error = problem);
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final ok = await vm.saveSportRanking(entry);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error = vm.error;
                      });
                    }
                  },
            child: Text(saving ? '저장 중…' : '성적 저장'),
          ),
        ],
      ),
    );
  }
}
