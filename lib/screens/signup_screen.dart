import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

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
    return Scaffold(
      // AppBar가 있으면 뒤로가기 버튼은 자동으로 생긴다 (4강)
      appBar: AppBar(title: const Text('회원가입')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _age,
              decoration: const InputDecoration(labelText: '나이', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.length < 4) ? '비밀번호는 4자 이상이어야 합니다.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('가입하기')),
          ],
        ),
      ),
    );
  }
}
