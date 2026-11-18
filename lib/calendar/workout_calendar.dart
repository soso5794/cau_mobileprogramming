import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../members/member_widgets.dart';
import '../theme/app_theme.dart';
import 'event_editor.dart';
import 'workout_event.dart';

class WorkoutCalendar extends StatefulWidget {
  const WorkoutCalendar({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  State<WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar> {
  late DateTime selected, month;
  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    selected = DateTime(now.year, now.month, now.day);
    month = DateTime(now.year, now.month);
  }

  void shift(int by) => setState(() {
    month = DateTime(month.year, month.month + by);
    selected = month;
  });
  Future<void> edit([WorkoutEvent? event]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => EventEditor(date: selected, event: event),
  );
  Future<void> remove(WorkoutEvent e) async {
    final vm = context.read<AppState>().members;
    final owner = vm.profile!.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('일정을 삭제할까요?'),
        content: Text(e.title),
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
    );
    if (confirmed == true && mounted) {
      await vm.deleteEvent(e.id, ownerId: owner);
    }
  }

  String clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    final p = vm.profile;
    if (p == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday % 7;
    final cells = ((count + offset) / 7).ceil() * 7;
    final events = p.events.where((e) => e.occursOn(selected)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '내 운동 캘린더',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text('개인 일정 · 이 기기에 저장'),
          Row(
            children: [
              IconButton(
                key: const Key('calendar-prev'),
                tooltip: '이전 달',
                onPressed: month.isAfter(DateTime(2000))
                    ? () => shift(-1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                key: const Key('calendar-next'),
                tooltip: '다음 달',
                onPressed: month.isBefore(DateTime(2100, 12))
                    ? () => shift(1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(child: Center(child: Text(d))),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 58,
            ),
            itemBuilder: (c, i) {
              final day = i - offset + 1;
              if (day < 1 || day > count) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, day);
              final active = date == selected;
              final hasEvents = p.events.any((e) => e.occursOn(date));
              final today = DateUtils.isSameDay(date, DateTime.now());
              return Semantics(
                label: '${month.month}월 $day일${hasEvents ? ', 일정 있음' : ''}',
                selected: active,
                button: true,
                child: InkWell(
                  key: ValueKey('calendar-day-$day'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => selected = date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: active ? scheme.primary : null,
                      borderRadius: BorderRadius.circular(12),
                      border: today ? Border.all(color: scheme.primary) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$day',
                            maxLines: 1,
                            style: TextStyle(
                              color: active ? scheme.onPrimary : null,
                            ),
                          ),
                        ),
                        if (hasEvents)
                          Icon(
                            Icons.circle,
                            size: 5,
                            color: active ? scheme.onPrimary : scheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${selected.month}월 ${selected.day}일 · ${events.length}개 일정',
              ),
              TextButton(
                onPressed: () => setState(() {
                  final n = DateTime.now();
                  selected = DateTime(n.year, n.month, n.day);
                  month = DateTime(n.year, n.month);
                }),
                child: const Text('오늘'),
              ),
            ],
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('이 날짜에는 운동 일정이 없어요.'),
            ),
          for (final e in events)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      e.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${clock(e.start)} · ${e.minutes}분 · ${e.sport}${e.place.isEmpty ? '' : ' · ${e.place}'}',
                    ),
                    if (e.notes.isNotEmpty) Text(e.notes),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          label: Text(e.completed ? '운동 완료' : '예정'),
                          selected: e.completed,
                          onSelected: vm.busy
                              ? null
                              : (v) => vm.saveEvent(
                                  e.withCompleted(v),
                                  ownerId: p.id,
                                ),
                        ),
                        IconButton(
                          tooltip: '일정 수정',
                          onPressed: vm.busy ? null : () => edit(e),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '일정 삭제',
                          onPressed: vm.busy ? null : () => remove(e),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            key: const Key('calendar-add'),
            onPressed: vm.busy ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('운동 일정 추가'),
          ),
          if (vm.error != null) MemberError(vm),
        ],
      ),
    );
  }
}
