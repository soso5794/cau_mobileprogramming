import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../community/recruitment_card.dart';
import '../members/member_widgets.dart';
import '../routing/app_routes.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key, required this.sport});
  final String sport;
  @override
  Widget build(BuildContext context) {
    final posts = context
        .watch<AppState>()
        .members
        .operations
        .posts
        .where((p) => p.sport == sport)
        .toList();
    return MemberPage(
      title: '$sport 커뮤니티',
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.community),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '함께할 $sport 메이트',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('같은 종목을 즐기는 사람들의 모집글을 둘러보세요.'),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () =>
                context.push('/sports/${AppRoutes.sportId(sport)}/setup'),
            icon: const Icon(Icons.tune),
            label: const Text('내 종목 프로필 수정'),
          ),
          const SizedBox(height: 16),
          if (posts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('아직 이 종목의 모집글이 없어요. 다른 관심 종목도 둘러보세요.'),
              ),
            ),
          for (final post in posts) RecruitmentCard(post: post),
          const SizedBox(height: 12),
          const Text(
            '예시 모집과 운영자 등록 모집을 구분해 표시합니다. 일반 회원의 모집 작성·참가 신청은 준비 중입니다.',
          ),
        ],
      ),
    );
  }
}
