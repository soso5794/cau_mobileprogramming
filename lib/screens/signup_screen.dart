import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../theme/app_theme.dart';

/// PDF 2페이지 ③: 새로가입 클릭 시 → 회원정보 입력 (이름, 나이, 아이디, 비밀번호)
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // [3강] Form + GlobalKey<FormState> 로 여러 입력칸을 한 번에 검사(validate)
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _id = TextEditingController();
  final _pw = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return; // 하나라도 틀리면 중단

    final ok = context.read<AppState>().register(
          name: _name.text.trim(),
          age: int.parse(_age.text.trim()),
          id: _id.text.trim(),
          password: _pw.text,
        );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 아이디입니다.')),
      );
      return;
    }
    // [4강] pop으로 값을 돌려준다 → 로그인 화면의 await가 이 아이디를 받는다.
    Navigator.pop(context, _id.text.trim());
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '필수 입력 항목입니다.' : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // AppBar가 있으면 뒤로가기 버튼은 자동으로 생긴다 (4강)
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('반가워요! 👋',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('운동 추천을 위해 기본 정보를 알려주세요.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            SectionCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: appInputDecoration(context,
                        label: '이름', icon: Icons.badge_outlined),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _age,
                    decoration: appInputDecoration(context,
                        label: '나이', icon: Icons.cake_outlined),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (_required(v) != null) return _required(v);
                      final n = int.tryParse(v!.trim());
                      if (n == null || n <= 0 || n > 120) return '올바른 나이를 입력해주세요.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _id,
                    decoration: appInputDecoration(context,
                        label: '아이디', icon: Icons.person_outline),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pw,
                    obscureText: true,
                    decoration: appInputDecoration(context,
                        label: '비밀번호 (4자 이상)', icon: Icons.lock_outline),
                    validator: (v) =>
                        (v == null || v.length < 4) ? '비밀번호는 4자 이상이어야 합니다.' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: const Text('가입하기'),
            ),
          ],
        ),
      ),
    );
  }
}
