import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';
import 'member_models.dart';
import 'member_widgets.dart';
import 'profile_draft.dart';
import 'sport_questions.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    super.key,
    this.onboarding = false,
    this.managedProfile,
  });
  final bool onboarding;
  final MemberProfile? managedProfile;
  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final ProfileDraft draft;
  bool _exitAllowed = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    draft = ProfileDraft(
      widget.managedProfile ?? context.read<AppState>().members.profile!,
    );
  }

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  void leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        widget.managedProfile == null ? AppRoutes.me : AppRoutes.admin,
      );
    }
  }

  Future<void> exit() async {
    if (_confirming || context.read<AppState>().members.busy) return;
    _confirming = true;
    final discard = !draft.dirty || await confirmDiscard(context);
    if (!mounted) return;
    _confirming = false;
    if (discard) {
      if (widget.onboarding) {
        await skip();
        return;
      }
      setState(() => _exitAllowed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) leave();
      });
    }
  }

  String get destination =>
      AppRoutes.safeReturnTo(
        GoRouterState.of(context).uri.queryParameters['from'],
      ) ??
      AppRoutes.sports;
  Future<void> skip() async {
    final vm = context.read<AppState>().members;
    final target = destination;
    if (await vm.save(draft.original.copyWith(onboarding: 'deferred')) &&
        mounted) {
      context.go(target);
    }
  }

  Future<void> save() async {
    if (!draft.validateAll()) return;
    final vm = context.read<AppState>().members;
    final target = widget.managedProfile != null
        ? AppRoutes.admin
        : widget.onboarding
        ? destination
        : AppRoutes.me;
    final saved = widget.managedProfile == null
        ? await vm.save(draft.value(onboarding: 'complete'))
        : await vm.saveManagedProfile(draft.value(onboarding: 'complete'));
    if (saved && mounted) {
      setState(() => _exitAllowed = true);
      context.go(target);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('운동 프로필을 저장했어요.')));
    }
  }

  Widget field(
    String label,
    String key, {
    bool number = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      key: ValueKey('common-$key'),
      initialValue: draft.common[key] ?? '',
      keyboardType: number ? TextInputType.number : TextInputType.text,
      maxLines: lines,
      maxLength: key == 'bio' ? 200 : null,
      decoration: memberInput(label),
      onChanged: (v) => draft.setCommon(key, v),
    ),
  );
  Widget commonChoice(
    String label,
    String key,
    List<String> options, {
    bool multi = false,
  }) => ChoiceGroup(
    label: label,
    options: options,
    selected: (draft.common[key] ?? '').split(',').toSet(),
    onSelected: (v) =>
        multi ? draft.toggleCommon(key, v) : draft.setCommon(key, v),
  );
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => PopScope<Object?>(
        canPop:
            _exitAllowed || (!widget.onboarding && !draft.dirty && !vm.busy),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) exit();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.managedProfile != null
                  ? '회원 프로필 관리'
                  : widget.onboarding
                  ? '운동 프로필 설정'
                  : '프로필 편집',
            ),
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: exit,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              if (widget.onboarding)
                TextButton(
                  onPressed: vm.busy ? null : exit,
                  child: const Text('나중에'),
                ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  key: ValueKey(draft.step),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: (draft.step + 1) / draft.steps.length,
                      ),
                      const SizedBox(height: 12),
                      Text('${draft.step + 1} / ${draft.steps.length}'),
                      const SizedBox(height: 12),
                      MemberHeading(
                        draft.steps[draft.step],
                        draft.step == draft.steps.length - 1
                            ? '크루에게 보여줄 소개를 마지막으로 적어주세요.'
                            : '나에게 맞는 운동 메이트를 찾기 위한 정보예요.',
                      ),
                      if (draft.step == 0) ...[
                        TextFormField(
                          key: const Key('profile-nickname'),
                          initialValue: draft.nickname,
                          decoration: memberInput('닉네임'),
                          onChanged: draft.setName,
                        ),
                        commonChoice('성별 (선택)', 'gender', [
                          '여성',
                          '남성',
                          '기타',
                          '응답 안 함',
                        ]),
                        field('나이 (선택)', 'age', number: true),
                        field('키 · cm (선택)', 'height', number: true),
                        const SizedBox(height: 12),
                        const Text('성별·나이·키는 선택 정보이며 팀에 자동 공개하지 않아요.'),
                      ] else if (draft.step == 1) ...[
                        ChoiceGroup(
                          label: '함께할 운동',
                          options: memberSports,
                          selected: draft.sports.toSet(),
                          onSelected: draft.toggleSport,
                        ),
                        if (draft.sports.any(
                          (e) => !draft.original.sports.contains(e),
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '새로 추가한 운동(${draft.sports.where((e) => !draft.original.sports.contains(e)).join(', ')})은 '
                              '다음 단계에서 실력·횟수 같은 정보를 입력해요.',
                              key: const Key('new-sport-hint'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        field('주 활동 지역 · 시/구', 'region'),
                        field('주로 사용하는 장소 (선택)', 'place'),
                        commonChoice('선호 시간대', 'times', [
                          '평일 오전',
                          '평일 오후',
                          '평일 저녁',
                          '주말 오전',
                          '주말 오후',
                          '주말 저녁',
                        ], multi: true),
                        commonChoice('커뮤니티 이용 목적', 'purposes', [
                          '친목·취미',
                          '연습·성장',
                          '경기·승부',
                          '운동 습관',
                          '팀·크루 가입',
                        ], multi: true),
                      ] else if (draft.step < draft.steps.length - 1)
                        SportQuestions(
                          sport: draft.sports[draft.step - 2],
                          answers:
                              draft.answers[draft.sports[draft.step - 2]] ?? {},
                          onChanged: (k, v) => draft.setAnswer(
                            draft.sports[draft.step - 2],
                            k,
                            v,
                          ),
                        )
                      else ...[
                        field('자기소개 (선택)', 'bio', lines: 4),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draft.nickname,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(draft.sports.join(' · ')),
                                Text(draft.common['region'] ?? ''),
                                Text(draft.common['times'] ?? ''),
                                for (final sport in draft.sports)
                                  Text(
                                    '$sport · ${draft.answers[sport]?['frequency'] ?? ''} · ${draft.answers[sport]?['duration'] ?? ''}',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Text('알림은 가입 후 내정보 → 설정에서 바꿀 수 있어요.'),
                      ],
                      if (draft.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            draft.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      MemberError(vm),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('profile-next'),
                        onPressed: vm.busy
                            ? null
                            : draft.step == draft.steps.length - 1
                            ? save
                            : draft.next,
                        child: Text(
                          vm.busy
                              ? '저장 중…'
                              : draft.step == draft.steps.length - 1
                              ? '설정 완료'
                              : '다음',
                        ),
                      ),
                      if (draft.step > 0)
                        TextButton(
                          onPressed: vm.busy ? null : draft.back,
                          child: const Text('이전 질문'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
