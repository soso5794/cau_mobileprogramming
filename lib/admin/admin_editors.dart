import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../community/community_data.dart';
import '../members/member_models.dart';
import '../members/member_widgets.dart';
import '../models/app_state.dart';
import 'operations_data.dart';

class RankingEditor extends StatefulWidget {
  const RankingEditor({super.key, this.entry});
  final RankingEntry? entry;
  @override
  State<RankingEditor> createState() => _RankingEditorState();
}

class _RankingEditorState extends State<RankingEditor> {
  late final name = TextEditingController(text: widget.entry?.name ?? '');
  late final count = TextEditingController(text: '${widget.entry?.count ?? 0}');
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.entry == null ? '랭킹 항목 추가' : '랭킹 수정'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('rank-name'),
                  controller: name,
                  enabled: !saving,
                  validator: MemberValidation.nickname,
                  decoration: memberInput('표시 이름'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('rank-count'),
                  controller: count,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      MemberValidation.number(v, 0, 9999, required: true),
                  decoration: memberInput('이번 주 운동 횟수'),
                ),
                if (error != null)
                  Text(
                    error!,
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
          key: const Key('rank-save'),
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => saving = true);
                  final vm = context.read<AppState>().members;
                  final ok = await vm.saveRanking(
                    RankingEntry(
                      id:
                          widget.entry?.id ??
                          'rank-${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text.trim(),
                      count: int.parse(count.text),
                    ),
                  );
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
          child: Text(saving ? '저장 중…' : '랭킹 저장'),
        ),
      ],
    ),
  );
}

class RecruitmentEditor extends StatefulWidget {
  const RecruitmentEditor({super.key, this.post});
  final RecruitmentPreview? post;
  @override
  State<RecruitmentEditor> createState() => _RecruitmentEditorState();
}

class _RecruitmentEditorState extends State<RecruitmentEditor> {
  late final Map<String, TextEditingController> fields = {
    'title': TextEditingController(text: widget.post?.title ?? ''),
    'time': TextEditingController(text: widget.post?.time ?? ''),
    'place': TextEditingController(text: widget.post?.place ?? ''),
    'condition': TextEditingController(text: widget.post?.condition ?? ''),
    'people': TextEditingController(text: widget.post?.people ?? ''),
    'description': TextEditingController(text: widget.post?.description ?? ''),
    'equipment': TextEditingController(text: widget.post?.equipment ?? ''),
  };
  late String sport = widget.post?.sport ?? '농구';
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  static const labels = {
    'title': '모집 제목',
    'time': '일시 (예: 11/28 18:00)',
    'place': '장소',
    'condition': '모집 조건',
    'people': '인원 (예: 3/6명)',
    'description': '모집 설명',
    'equipment': '준비물',
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.post == null ? '모집글 등록' : '모집글 수정'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: sport,
                  isExpanded: true,
                  decoration: memberInput('운동 종목'),
                  items: AppState.allSports
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: saving ? null : (v) => setState(() => sport = v!),
                ),
                for (final field in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextFormField(
                      key: Key('post-${field.key}'),
                      controller: field.value,
                      enabled: !saving,
                      maxLines: field.key == 'description' ? 3 : 1,
                      maxLength: field.key == 'title' ? 60 : 1000,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? '내용을 입력해주세요.' : null,
                      decoration: memberInput(labels[field.key]!),
                    ),
                  ),
                const Text('운영자 등록 글로 표시됩니다. 실제 참가 신청·시설 예약 기능은 포함하지 않습니다.'),
                if (error != null)
                  Text(
                    error!,
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
          key: const Key('post-save'),
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => saving = true);
                  final vm = context.read<AppState>().members;
                  String value(String key) => fields[key]!.text.trim();
                  final ok = await vm.saveRecruitment(
                    RecruitmentPreview(
                      id:
                          widget.post?.id ??
                          'post-${DateTime.now().microsecondsSinceEpoch}',
                      sport: sport,
                      title: value('title'),
                      time: value('time'),
                      place: value('place'),
                      condition: value('condition'),
                      people: value('people'),
                      description: value('description'),
                      equipment: value('equipment'),
                      isDemo: false,
                    ),
                  );
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
          child: Text(saving ? '저장 중…' : '모집글 저장'),
        ),
      ],
    ),
  );
}
