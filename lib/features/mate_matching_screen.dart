import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../community/community_data.dart';
import '../members/member_models.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';
import 'mate_matcher.dart';
import 'workout_tier.dart';
import '../routing/app_routes.dart';

class MateMatchingScreen extends StatefulWidget {
  const MateMatchingScreen({super.key});

  @override
  State<MateMatchingScreen> createState() => _MateMatchingScreenState();
}

class _MateMatchingScreenState extends State<MateMatchingScreen> {
  String? _sport;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.members.profile;
    if (profile == null) return const SizedBox.shrink();
    final sports = profile.sports;
    final selected = sports.contains(_sport) ? _sport! : (sports.isEmpty ? '' : sports.first);
    final suggestions = selected.isEmpty
        ? const <_MateSuggestion>[]
        : _buildSuggestions(
            profile,
            app.members.matchingProfiles,
            app.members.operations.posts,
            selected,
          );
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 운동 메이트 매칭')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(
            '나와 잘 맞는 운동 메이트',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '실력·러닝 페이스·포지션·활동 지역·시간대·운동 경험을 종합해 잘 맞는 상대를 추천해요.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (sports.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.sports_outlined, size: 40),
                    const SizedBox(height: 8),
                    const Text('먼저 관심 운동을 등록해주세요.'),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.editProfile),
                      child: const Text('운동 프로필 설정'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sport in sports)
                  ChoiceChip(
                    label: Text(sport),
                    selected: sport == selected,
                    onSelected: (_) => setState(() => _sport = sport),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _MyMatchCriteria(profile: profile, sport: selected),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '추천 결과',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${suggestions.length}개', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            if (suggestions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('조건에 맞는 메이트나 모집글이 아직 없어요. 프로필을 보완하거나 직접 모집글을 등록해보세요.'),
                ),
              ),
            for (final suggestion in suggestions)
              _SuggestionCard(
                suggestion: suggestion,
                sport: selected,
                onOpenPost: suggestion.post == null
                    ? null
                    : () => context.push('/community/posts/${suggestion.post!.id}'),
                onOpenMember: suggestion.member == null
                    ? null
                    : () => _showMemberDetails(context, suggestion.member!, selected),
              ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '추천 점수는 현재 기기의 회원·예시 프로필과 모집글을 이용하는 설명 가능한 매칭 알고리즘으로 계산해요. 실제 회원 간 실시간 공유·초대 알림은 공용 서버 연동이 필요해요.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberDetails(BuildContext context, MemberProfile member, String sport) {
    final scheme = Theme.of(context).colorScheme;
    final answers = member.answers[sport] ?? const <String, String>{};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Icon(sportIcon(sport))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.nickname, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text('${member.common['region'] ?? '지역 미설정'} · ${sport} 메이트 · ${WorkoutTier.forXp(member.tierExperiencePoints).name}', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                sport == '런닝'
                    ? '러닝 페이스 ${answers['pace'] ?? '미설정'} · 목표 거리 ${answers['distance'] ?? '미설정'}'
                    : '실력 ${answers['skill'] ?? '미설정'} · 포지션 ${answers['positions'] ?? '무관'}',
              ),
              const SizedBox(height: 6),
              Text('선호 시간 ${member.common['times'] ?? '미설정'}'),
              Text('활동 티어 ${WorkoutTier.forXp(member.tierExperiencePoints).name} · ${member.tierExperiencePoints} XP'),
              const SizedBox(height: 10),
              Text(member.common['bio']?.trim().isNotEmpty == true ? member.common['bio']! : '등록된 자기소개가 없어요.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final text = '${member.nickname}님, 안녕하세요! $sport 같이 운동해보고 싶어서 연락드려요. 편한 시간에 이야기 나눠요.';
                  await Clipboard.setData(ClipboardData(text: text));
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메이트 초대 문구를 복사했어요.')));
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('초대 문구 복사'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MateSuggestion {
  const _MateSuggestion({this.member, this.post, required this.score, required this.reasons});
  final MemberProfile? member;
  final RecruitmentPreview? post;
  final int score;
  final List<String> reasons;
}

List<_MateSuggestion> _buildSuggestions(
  MemberProfile current,
  List<MemberProfile> profiles,
  List<RecruitmentPreview> posts,
  String sport,
) {
  final suggestions = <_MateSuggestion>[];
  for (final candidate in profiles) {
    if (candidate.id == current.id || !candidate.sports.contains(sport)) continue;
    final result = MateMatcher.evaluate(
      me: current,
      candidate: candidate,
      sport: sport,
    );
    final reasons = result.reasons;
    final score = result.score;
    suggestions.add(_MateSuggestion(
      member: candidate,
      score: score,
      reasons: reasons,
    ));
  }

  for (final post in posts) {
    if (post.sport != sport) continue;
    final reasons = <String>['관심 종목 모집'];
    var score = 38;
    final times = current.common['times'] ?? '';
    if ((times.contains('평일') && post.time.contains('평일')) ||
        (times.contains('주말') && (post.time.contains('토') || post.time.contains('일'))) ||
        (times.contains('저녁') && RegExp(r'1[7-9]|20|21').hasMatch(post.time)) ||
        (times.contains('오전') && RegExp(r'0[6-9]|10|11').hasMatch(post.time))) {
      score += 20;
      reasons.add('선호 시간대와 일정이 맞아요');
    } else {
      score += 8;
    }
    final region = current.common['region'] ?? '';
    if (region.isNotEmpty && (post.place.contains(region) || _sharesRegion(region, post.place))) {
      score += 15;
      reasons.add('활동 권역과 모집 장소가 겹쳐요');
    } else {
      score += 7;
    }
    final skill = current.answers[sport]?['skill'] ?? '';
    final condition = '${post.condition} ${post.description}';
    if (skill.isNotEmpty && condition.contains(skill)) {
      score += 12;
      reasons.add('모집 조건이 내 실력과 맞아요');
    } else {
      score += 8;
    }
    score += 10;
    suggestions.add(_MateSuggestion(post: post, score: score.clamp(0, 100).toInt(), reasons: reasons));
  }

  suggestions.sort((a, b) => b.score.compareTo(a.score));
  return suggestions.take(12).toList();
}

bool _sharesRegion(String a, String b) {
  const broadAreas = {
    '서울', '서울특별시', '경기', '경기도', '인천', '인천광역시',
    '부산', '부산광역시', '대구', '대구광역시', '대전', '대전광역시',
    '광주', '광주광역시', '울산', '울산광역시', '세종', '세종특별자치시',
    '강원', '강원도', '충북', '충청북도', '충남', '충청남도',
    '전북', '전라북도', '전남', '전라남도', '경북', '경상북도',
    '경남', '경상남도', '제주', '제주특별자치도',
  };
  final aParts = a.split(RegExp(r'\s+'));
  final bParts = b.split(RegExp(r'\s+'));
  return aParts.any(
    (part) => part.length >= 2 && !broadAreas.contains(part) && bParts.contains(part),
  );
}


class _MyMatchCriteria extends StatelessWidget {
  const _MyMatchCriteria({required this.profile, required this.sport});
  final MemberProfile profile;
  final String sport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answers = profile.answers[sport] ?? const <String, String>{};
    final details = [
      profile.common['region'] ?? '지역 미설정',
      profile.common['times'] ?? '시간 미설정',
      '활동 티어 ${WorkoutTier.forXp(profile.tierExperiencePoints).name}',
      answers['skill'] ?? (sport == '런닝' ? answers['pace'] ?? '페이스 미설정' : '실력 미설정'),
      answers['positions'] ?? '',
    ].where((e) => e.trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 매칭 기준', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final detail in details) Chip(label: Text(detail), visualDensity: VisualDensity.compact)]),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.sport,
    this.onOpenPost,
    this.onOpenMember,
  });
  final _MateSuggestion suggestion;
  final String sport;
  final VoidCallback? onOpenPost;
  final VoidCallback? onOpenMember;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final member = suggestion.member;
    final post = suggestion.post;
    final title = member?.nickname ?? post?.title ?? '운동 메이트';
    final subtitle = member != null
        ? '${member.common['region'] ?? '지역 미설정'} · ${member.common['times'] ?? '시간 미설정'} · ${WorkoutTier.forXp(member.tierExperiencePoints).name}'
        : '${post!.place} · ${post.time} · ${post.people}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(member != null ? Icons.person_rounded : sportIcon(sport), color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Text('${suggestion.score}점', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in suggestion.reasons.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                    child: Text(reason, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (post != null)
              FilledButton.tonalIcon(onPressed: onOpenPost, icon: const Icon(Icons.open_in_new), label: const Text('모집글 보기'))
            else
              OutlinedButton.icon(onPressed: onOpenMember, icon: const Icon(Icons.person_search_outlined), label: const Text('프로필 및 초대 문구 보기')),
            if (member?.isDemo == true)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('시연용 프로필', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
