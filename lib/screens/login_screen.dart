import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../members/member_models.dart';
import '../members/member_widgets.dart';
import '../routing/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _obscure = true, _remember = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String target(String path) => Uri(
    path: path,
    queryParameters: AppRoutes.returnQuery(
      GoRouterState.of(context).uri.queryParameters['from'],
    ),
  ).toString();
  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<AppState>().members.login(
      _email.text,
      _password.text,
      _remember,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    return MemberPage(
      title: '운동 Assist',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.sports_basketball_rounded,
                size: 56,
                color: Color(0xFF075B3D),
              ),
              const SizedBox(height: 24),
              const MemberHeading('함께 뛰는 일상', '나에게 맞는 운동 메이트를 만나보세요.'),
              const Text('로컬 프로토타입 · 실제 서비스 계정과 다른 이메일/비밀번호를 사용하세요.'),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                validator: MemberValidation.email,
                decoration: memberInput('이메일'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('login-password'),
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => submit(),
                validator: (v) => (v ?? '').isEmpty ? '비밀번호를 입력해주세요.' : null,
                decoration: memberInput(
                  '비밀번호',
                  error: vm.errorField == 'password' ? vm.error : null,
                  suffix: IconButton(
                    tooltip: _obscure ? '비밀번호 표시' : '비밀번호 숨기기',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('로그인 상태 유지'),
                value: _remember,
                onChanged: (v) => setState(() => _remember = v!),
              ),
              if (vm.errorField != 'password') MemberError(vm),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: vm.busy ? null : submit,
                child: Text(vm.busy ? '로그인 중…' : '로그인'),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => context.push(target(AppRoutes.reset)),
                    child: const Text('비밀번호 재설정'),
                  ),
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => context.push(target(AppRoutes.signup)),
                    child: const Text('회원가입'),
                  ),
                ],
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                onPressed: vm.busy
                    ? null
                    : () => context.push(target(AppRoutes.demo)),
                icon: const Icon(Icons.science_outlined),
                label: const Text('DEMO 계정으로 둘러보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
