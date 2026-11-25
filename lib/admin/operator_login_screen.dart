import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../members/member_widgets.dart';
import '../models/app_state.dart';
import 'admin_gateway.dart';

class OperatorLoginScreen extends StatefulWidget {
  const OperatorLoginScreen({super.key});
  @override
  State<OperatorLoginScreen> createState() => _OperatorLoginScreenState();
}

class _OperatorLoginScreenState extends State<OperatorLoginScreen> {
  final _password = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppState>().members;
    return MemberPage(
      title: '운영자 로그인',
      onBack: () => context.go('/login'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 56),
          const SizedBox(height: 20),
          const MemberHeading('운영자 전용', '회원정보·일정·랭킹·모집글을 관리합니다.'),
          const Text('계정: $operatorEmail'),
          const SizedBox(height: 12),
          const Text(
            'DEMO 계정과 별개입니다. 운영자 비밀번호로 로그인하며 현재 브라우저에 저장된 데이터를 관리합니다.',
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('operator-password'),
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: memberInput('운영자 비밀번호'),
            enabled: !vm.busy,
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('operator-login'),
            onPressed: vm.busy
                ? null
                : () async {
                    if (_password.text.isEmpty) return;
                    await vm.loginOperator(_password.text);
                  },
            child: Text(vm.busy ? '인증 중…' : '운영자 로그인'),
          ),
          MemberError(vm),
          const SizedBox(height: 12),
          const Text(
            '로그인 정보는 프로젝트의 server/.operator-login.txt에서 확인할 수 있습니다. 운영자 로그인은 앱 재시작 시 다시 필요합니다.',
          ),
        ],
      ),
    );
  }
}
