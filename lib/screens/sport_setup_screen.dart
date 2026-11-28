import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../members/member_widgets.dart';
import '../members/profile_draft.dart';
import '../members/sport_questions.dart';

class SportSetupScreen extends StatefulWidget {
  const SportSetupScreen({super.key, required this.sport, this.isNew = false});
  final String sport;

  /// true면 아직 내 운동에 없는 새 종목이다. 저장하면 운동 목록에도 추가된다.
  final bool isNew;
  @override
  State<SportSetupScreen> createState() => _SportSetupScreenState();
}

class _SportSetupScreenState extends State<SportSetupScreen> {
  late Map<String, String> _answers;
  String? _error;
  bool _dirty = false, _allowExit = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    _answers = {...context.read<AppState>().preferenceOf(widget.sport)};
  }

  Future<void> leave() async {
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
            context.go('/sports');
          }
        }
      });
    }
  }

  Future<void> save() async {
    setState(() => _error = ProfileDraft.validateSport(widget.sport, _answers));
    if (_error != null) return;
    final app = context.read<AppState>();
    final ok = widget.isNew
        ? await app.addSportWithPreference(widget.sport, _answers)
        : await app.saveSportPreference(widget.sport, _answers);
    if (ok && mounted) {
      setState(() => _allowExit = true);
      context.go('/me');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    return PopScope<Object?>(
      canPop: (!_dirty && !vm.busy) || _allowExit,
      onPopInvokedWithResult: (p, r) {
        if (!p && !vm.busy) leave();
      },
      child: MemberPage(
        title: widget.isNew
            ? '${widget.sport} 추가 · 운동 정보'
            : '${widget.sport} · 운동 프로필',
        onBack: () {
          if (!vm.busy) leave();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isNew
                  ? '새로 추가하는 운동이에요. 아래 정보를 입력하고 저장하면 내 운동에 추가돼요.'
                  : '저장하기 전까지 기존 프로필은 바뀌지 않아요.',
            ),
            SportQuestions(
              sport: widget.sport,
              answers: _answers,
              onChanged: (k, v) => setState(() {
                _answers[k] = v;
                _dirty = true;
              }),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            MemberError(vm),
            FilledButton(
              key: const Key('sport-save'),
              onPressed: vm.busy ? null : save,
              child: Text(widget.isNew ? '운동 추가하고 저장' : '운동 프로필 저장'),
            ),
          ],
        ),
      ),
    );
  }
}
