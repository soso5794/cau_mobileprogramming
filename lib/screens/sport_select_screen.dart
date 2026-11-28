import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../routing/app_routes.dart';

/// Community entry: interests saved in onboarding/profile, never a second survey.
class SportSelectScreen extends StatelessWidget {
  const SportSelectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final sports = context.watch<AppState>().selectedSports;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '나의 운동 커뮤니티',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '설문에서 고른 관심 종목이에요. 함께 운동할 메이트를 만나보세요.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('community-edit-interests'),
                onPressed: () => context.push(AppRoutes.editProfile),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('관심 종목 수정'),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.mates),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI 메이트 매칭'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.qrAttendance),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('QR 운동 인증'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (sports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined, size: 48),
                      SizedBox(height: 16),
                      Text('아직 선택한 관심 종목이 없어요.'),
                      SizedBox(height: 8),
                      Text('관심 종목 수정에서 함께할 운동을 골라주세요.'),
                    ],
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 3
                    : constraints.maxWidth >= 480
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final sport in sports)
                      SizedBox(
                        width: width,
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('community-sport-$sport'),
                            onTap: () => context.push(
                              '/community/${AppRoutes.sportId(sport)}',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: scheme.primaryContainer,
                                    child: Icon(
                                      sportIcon(sport),
                                      color: scheme.onPrimaryContainer,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '$sport 커뮤니티',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '모집글 둘러보기 →',
                                    style: TextStyle(color: scheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
