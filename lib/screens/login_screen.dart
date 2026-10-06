import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

/// PDF 2페이지: 로그인 페이지
/// ① 아이디 입력 ② 비밀번호 입력 ③ 새로가입 → 회원정보 입력 화면 ④ 로그인 버튼
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // [3강] TextField의 값을 읽으려면 TextEditingController를 쓴다.
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  @override
  void dispose() {
    // [5강] initState에서 만든 것 / State가 들고 있는 컨트롤러는 dispose에서 정리 (메모리 누수 방지)
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _login() {
    final ok = context.read<AppState>().login(
          _idController.text.trim(),
          _pwController.text,
        );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 확인해주세요.')),
      );
      return;
    }
    // [4강] pushReplacement: 로그인 화면을 스택에서 빼고 홈으로 교체 → 뒤로가기로 로그인에 못 돌아옴
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _goSignup() async {
    // [4강] await Navigator.push → 회원가입 화면이 pop(context, 값)으로 돌려준 아이디를 받는다.
    final newId = await Navigator.pushNamed(context, '/signup');
    if (!mounted) return; // await 뒤에는 화면이 아직 살아있는지 확인
    if (newId is String) {
      _idController.text = newId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$newId 님, 가입이 완료되었습니다. 로그인 해주세요!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        // 키보드가 올라와도 화면이 넘치지(overflow) 않도록 스크롤 가능하게 감싼다.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 로고: "운동 Assist" + 체크 아이콘
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('운동 ',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    Text('Assist',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: primary)),
                    Icon(Icons.check, size: 40, color: primary),
                  ],
                ),
                const SizedBox(height: 80),
                // ① 아이디
                const Text('아이디', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                // ② 비밀번호
                const Text('비밀번호', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _pwController,
                  obscureText: true, // 비밀번호 가리기
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 8),
                // ③ 새로가입  ④ 로그인
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: _goSignup, child: const Text('새로가입')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _login, child: const Text('로그인')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
