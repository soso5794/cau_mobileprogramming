import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/sport_icons.dart';
import '../members/member_widgets.dart';
import '../routing/app_routes.dart';
import 'community_data.dart';

class RecruitmentCard extends StatelessWidget {
  const RecruitmentCard({super.key, required this.post});
  final RecruitmentPreview post;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('recruitment-${post.id}'),
        onTap: () => context.push('/community/posts/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(sportIcon(post.sport), color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.sport,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    post.sourceLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${post.time} · ${post.place}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(post.condition),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(post.people),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecruitmentDetailScreen extends StatelessWidget {
  const RecruitmentDetailScreen({super.key, required this.post});
  final RecruitmentPreview post;
  @override
  Widget build(BuildContext context) => MemberPage(
    title: '모집글 상세',
    onBack: () =>
        context.canPop() ? context.pop() : context.go(AppRoutes.community),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Chip(
          label: Text(post.isDemo ? '예시 모집 · 실제 신청 불가' : '${post.sourceLabel} · 참가 신청 준비 중'),
        ),
        const SizedBox(height: 16),
        Text(
          post.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text('${post.sport} · ${post.people}'),
        const SizedBox(height: 12),
        Text(
          '일시  ${post.time}\n장소  ${post.place}\n모집 조건  ${post.condition}',
          style: const TextStyle(height: 1.8),
        ),
        const Divider(height: 32),
        Text(post.description, style: const TextStyle(height: 1.7)),
        const SizedBox(height: 24),
        Text('준비물', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(post.equipment),
        if (post.recruitmentInput != null) ...[
          const SizedBox(height: 12),
          if (post.recruitmentInput!.location != null) ...[
            if (post.recruitmentInput!.location!.address.isNotEmpty) Text('주소: ${post.recruitmentInput!.location!.address}'),
            Text('지도 위치 지정됨 (${post.recruitmentInput!.location!.latitude.toStringAsFixed(5)}, ${post.recruitmentInput!.location!.longitude.toStringAsFixed(5)})'),
          ],
          Text('병합 허용: ${post.recruitmentInput!.allowMerge ? '예' : '아니오'}'),
          if (post.extraConditions.isNotEmpty)
            Text('추가 조건: ${post.extraConditions.join(' · ')}'),
        ],
        const SizedBox(height: 24),
        Text(
          post.isDemo
              ? '화면 확인용 모집글입니다. 일정·장소는 실제 모임이나 예약을 의미하지 않으며, 참가 신청은 아직 지원하지 않아요.'
              : post.isMemberPost
              ? '이 기기에 저장된 회원 모집글입니다. 다른 기기와 공유되지 않으며 참가 신청은 아직 지원하지 않아요.'
              : '운영자가 등록한 모집글입니다. 앱 내 참가 신청·시설 예약은 아직 지원하지 않아요.',
        ),
        const SizedBox(height: 20),
        const FilledButton(onPressed: null, child: Text('참가 신청 준비 중')),
        TextButton(
          onPressed: () =>
              context.go('/community/${AppRoutes.sportId(post.sport)}'),
          child: Text('${post.sport} 커뮤니티 보기'),
        ),
      ],
    ),
  );
}
