import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../members/member_models.dart';
import '../members/member_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _obscure = true, _agreed = false;
  String? _agreementError;
  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _agreementError = _agreed ? null : '프로토타입 이용 안내를 확인해주세요.');
    if (!valid || !_agreed) return;
    await context.read<AppState>().members.signUp(
      _name.text,
      _email.text,
      _password.text,
      _agreed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    return MemberPage(
      title: '회원가입',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MemberHeading('계정을 만들어볼까요?', '계정을 만든 뒤 운동 프로필을 설정해요.'),
            TextFormField(
              key: const Key('signup-name'),
              controller: _name,
              validator: MemberValidation.nickname,
              decoration: memberInput(
                '닉네임',
                hint: '크루에게 보여줄 이름',
                error: vm.errorField == 'nickname' ? vm.error : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('signup-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: MemberValidation.email,
              decoration: memberInput(
                '이메일',
                error: vm.errorField == 'email' ? vm.error : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('signup-password'),
              controller: _password,
              obscureText: _obscure,
              validator: MemberValidation.password,
              decoration: memberInput(
                '비밀번호',
                hint: '영문·숫자 포함 8자 이상',
                suffix: IconButton(
                  tooltip: '비밀번호 표시 전환',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('signup-confirm'),
              controller: _confirm,
              obscureText: _obscure,
              validator: (v) => v == _password.text && v!.isNotEmpty
                  ? null
                  : '비밀번호가 일치하지 않아요.',
              decoration: memberInput('비밀번호 확인'),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '학습용 로컬 프로토타입입니다. 입력 정보는 이 기기에 저장되며 서버 계정 생성이나 이메일 인증은 진행하지 않아요. 실제 개인정보와 다른 곳에서 쓰는 비밀번호는 입력하지 마세요.',
                ),
              ),
            ),
            CheckboxListTile(
              key: const Key('signup-agreement'),
              contentPadding: EdgeInsets.zero,
              title: const Text('프로토타입 이용·기기 저장 안내를 확인했어요'),
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v!),
            ),
            if (_agreementError != null)
              Text(
                _agreementError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (vm.errorField != 'nickname' && vm.errorField != 'email')
              MemberError(vm),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('signup-submit'),
              onPressed: vm.busy ? null : submit,
              child: Text(vm.busy ? '계정 만드는 중…' : '계정 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}
