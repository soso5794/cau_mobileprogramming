import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import 'member_repository.dart';
import 'member_models.dart';
import 'member_widgets.dart';

class DemoAccountScreen extends StatelessWidget {
  const DemoAccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    return MemberPage(
      title: 'DEMO 계정 선택',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MemberHeading('어떤 메이트가 되어볼까요?', '아래 프로필·팀·티어는 시연용 가상 데이터예요.'),
          for (final p in MemberRepository.demoProfiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p.nickname,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('${p.sports.join(' · ')} · ${p.common['region']}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: Key(p.id),
                        onPressed: vm.busy ? null : () => vm.useDemo(p.id),
                        child: const Text('이 계정으로 둘러보기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          MemberError(vm),
        ],
      ),
    );
  }
}

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _requested = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MemberPage(
    title: '비밀번호 재설정',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MemberHeading('계정에 다시 접속하기', '이메일 재설정 흐름을 미리 확인할 수 있어요.'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: MemberValidation.email,
            decoration: memberInput('이메일'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                setState(() => _requested = true);
              }
            },
            child: const Text('재설정 안내 확인'),
          ),
          if (_requested)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                '데모 안내: 메일을 보내지 않았으며 비밀번호도 변경되지 않았어요. 실제 서비스에서는 인증된 재설정 링크가 필요합니다. 지금은 DEMO 계정을 선택하거나 새 로컬 계정을 만들어주세요.',
              ),
            ),
        ],
      ),
    ),
  );
}
