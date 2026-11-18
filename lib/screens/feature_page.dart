import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 내정보에서 여는 기존 기능(주간 계획·분석·AI)을 새 하단 메뉴 안에서 보여준다.
class FeaturePage extends StatelessWidget {
  const FeaturePage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            onPressed: () => context.go('/me'),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: child,
      );
}
