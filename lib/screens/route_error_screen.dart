import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, this.message = '요청한 화면을 찾을 수 없어요.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AppState>().loginId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('화면 안내')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 64),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(
                  signedIn ? AppRoutes.sports : AppRoutes.login,
                ),
                child: Text(signedIn ? '운동 선택으로' : '로그인으로'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
