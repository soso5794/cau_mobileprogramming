import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../members/member_widgets.dart';
import '../models/app_state.dart';
import 'workout_event.dart';

class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    required this.date,
    this.event,
    this.managedOwnerId,
  });
  final String? managedOwnerId;
  final DateTime date;
  final WorkoutEvent? event;
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final TextEditingController title, place, notes, duration;
  late DateTime date;
  late TimeOfDay time;
  late String sport, owner;
  late final String id;
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final vm = context.read<AppState>().members;
    final p = widget.managedOwnerId == null
        ? vm.profile!
        : vm.managedMembers.firstWhere((p) => p.id == widget.managedOwnerId);
    owner = p.id;
    final e = widget.event;
    id = e?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    title = TextEditingController(text: e?.title ?? '');
    place = TextEditingController(text: e?.place ?? '');
    notes = TextEditingController(text: e?.notes ?? '');
    duration = TextEditingController(text: '${e?.minutes ?? 60}');
    sport = e?.sport ?? p.sports.firstOrNull ?? '농구';
    date = e?.start ?? widget.date;
    time = e == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay.fromDateTime(e.start);
  }

  @override
  void dispose() {
    title.dispose();
    place.dispose();
    notes.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final vm = context.read<AppState>().members;
    final e = WorkoutEvent(
      id: id,
      title: title.text.trim(),
      sport: sport,
      start: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      minutes: int.tryParse(duration.text) ?? 0,
      place: place.text.trim(),
      notes: notes.text.trim(),
      completed: widget.event?.completed ?? false,
    );
    final issue = e.validate();
    if (issue != null) {
      setState(() => error = issue);
      return;
    }
    final ownerProfile = widget.managedOwnerId == null
        ? vm.profile
        : vm.managedMembers.where((p) => p.id == owner).firstOrNull;
    if (ownerProfile?.events.any(e.overlaps) == true) {
      final allow = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('겹치는 일정이 있어요'),
          content: const Text('같은 시간대에 다른 운동 일정이 있어요. 그래도 저장할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('시간 수정'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('그대로 저장'),
            ),
          ],
        ),
      );
      if (!mounted || allow != true) return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = widget.managedOwnerId == null
        ? await vm.saveEvent(e, ownerId: owner)
        : await vm.saveManagedEvent(owner, e);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = vm.error ?? '저장하지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.event == null ? '운동 일정 추가' : '운동 일정 수정'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('event-title'),
                controller: title,
                maxLength: 60,
                enabled: !saving,
                decoration: memberInput('일정 제목'),
              ),
              DropdownButtonFormField<String>(
                initialValue: sport,
                isExpanded: true,
                decoration: memberInput('운동'),
                items: {...AppState.allSports, sport}
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: saving ? null : (v) => setState(() => sport = v!),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text('${date.year}.${date.month}.${date.day}'),
                    onPressed: saving
                        ? null
                        : () async {
                            final next = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (mounted && next != null) {
                              setState(() => date = next);
                            }
                          },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(time.format(context)),
                    onPressed: saving
                        ? null
                        : () async {
                            final next = await showTimePicker(
                              context: context,
                              initialTime: time,
                            );
                            if (mounted && next != null) {
                              setState(() => time = next);
                            }
                          },
                  ),
                ],
              ),
              TextField(
                key: const Key('event-duration'),
                controller: duration,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: memberInput('운동 시간 · 분'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: place,
                enabled: !saving,
                maxLength: 100,
                decoration: memberInput('장소 (선택)'),
              ),
              TextField(
                controller: notes,
                enabled: !saving,
                maxLength: 500,
                maxLines: 3,
                decoration: memberInput('메모 (선택)'),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('event-save'),
          onPressed: saving ? null : save,
          child: Text(saving ? '저장 중…' : '일정 저장'),
        ),
      ],
    ),
  );
}
