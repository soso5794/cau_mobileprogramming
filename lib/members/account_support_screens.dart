import 'dart:async';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _challenge, _requestedEmail;
  bool _complete = false, _hidePassword = true;
  DateTime? _expiresAt, _resendAt;
  Timer? _timer;

  int secondsUntil(DateTime? date) => date == null
      ? 0
      : ((date.difference(DateTime.now()).inMilliseconds / 1000).ceil()).clamp(
          0,
          600,
        );

  Future<void> _request() async {
    final emailError = MemberValidation.email(_email.text);
    if (emailError != null) {
      _form.currentState!.validate();
      return;
    }
    final vm = context.read<AppState>().members;
    final email = MemberValidation.normalizeEmail(_email.text);
    setState(() {
      _challenge = null;
      _code.clear();
    });
    final id = await vm.requestPasswordReset(email);
    if (!mounted || id == null) return;
    setState(() {
      _challenge = id;
      _requestedEmail = email;
      _expiresAt = DateTime.now().add(const Duration(minutes: 10));
      _resendAt = DateTime.now().add(const Duration(seconds: 60));
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate() || _challenge == null) return;
    final ok = await context.read<AppState>().members.resetPassword(
      _requestedEmail!,
      _challenge!,
      _code.text,
      _password.text,
    );
    if (!mounted || !ok) return;
    _timer?.cancel();
    _password.clear();
    _confirm.clear();
    _code.clear();
    setState(() => _complete = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    final remaining = secondsUntil(_expiresAt);
    final resend = secondsUntil(_resendAt);
    return MemberPage(
      title: '비밀번호 재설정',
      child: _complete
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle_outline, size: 56),
                const MemberHeading(
                  '비밀번호를 변경했어요',
                  '프로필·설문·일정은 그대로 유지돼요. 새 비밀번호로 로그인해주세요.',
                ),
                FilledButton(
                  key: const Key('reset-login'),
                  onPressed: () => context.go('/login'),
                  child: const Text('로그인으로 돌아가기'),
                ),
              ],
            )
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MemberHeading(
                    '계정에 다시 접속하기',
                    '가입한 이메일로 인증번호를 받고 새 비밀번호를 설정하세요.',
                  ),
                  const Text(
                    '가입했던 기기·브라우저에서 진행해주세요. 다른 기기에 저장된 계정은 여기서 복구할 수 없어요.',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('reset-email'),
                    controller: _email,
                    enabled: !vm.busy && _challenge == null,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: MemberValidation.email,
                    decoration: memberInput('가입한 이메일'),
                  ),
                  const SizedBox(height: 20),
                  if (_challenge == null)
                    FilledButton(
                      key: const Key('reset-request'),
                      onPressed: vm.busy ? null : _request,
                      child: Text(vm.busy ? '인증메일 요청 중…' : '인증번호 받기'),
                    ),
                  if (_challenge != null) ...[
                    Text('$_requestedEmail로 인증메일을 보냈어요. 스팸함도 확인해주세요.'),
                    const SizedBox(height: 8),
                    Text(
                      remaining > 0
                          ? '남은 시간 ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                          : '인증번호가 만료됐어요. 새 인증번호를 요청해주세요.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('reset-code'),
                      controller: _code,
                      enabled: !vm.busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                          ? null
                          : '인증번호 6자리를 입력해주세요.',
                      decoration: memberInput('인증번호 6자리'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('reset-password'),
                      controller: _password,
                      enabled: !vm.busy,
                      obscureText: _hidePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: MemberValidation.password,
                      decoration: memberInput('새 비밀번호').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('reset-confirm'),
                      controller: _confirm,
                      enabled: !vm.busy,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: (v) =>
                          v == _password.text ? null : '비밀번호가 일치하지 않아요.',
                      decoration: memberInput('새 비밀번호 확인'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('reset-submit'),
                      onPressed: vm.busy || remaining == 0 ? null : _reset,
                      child: Text(vm.busy ? '인증 및 변경 중…' : '인증하고 비밀번호 변경'),
                    ),
                    TextButton(
                      key: const Key('reset-resend'),
                      onPressed: vm.busy || resend > 0 ? null : _request,
                      child: Text(
                        resend > 0 ? '인증번호 다시 받기 ($resend초 후)' : '인증번호 다시 받기',
                      ),
                    ),
                    TextButton(
                      onPressed: vm.busy
                          ? null
                          : () {
                              _timer?.cancel();
                              setState(() {
                                _challenge = null;
                                _code.clear();
                                _password.clear();
                                _confirm.clear();
                              });
                            },
                      child: const Text('다른 이메일 입력'),
                    ),
                  ],
                  MemberError(vm),
                ],
              ),
            ),
    );
  }
}
