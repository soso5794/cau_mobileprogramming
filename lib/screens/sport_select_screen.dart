import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';
import '../models/sport_icons.dart';
import '../theme/app_theme.dart';

/// PDF 3페이지: 선호 운동 선택 화면 (하단 탭 0번)
/// ① 로그인 후 등장, 큰 ⊕ 버튼
/// ② ⊕ 누르면 선호 운동 여러 개 선택 가능 (체크 형식)
/// ③ 선택한 운동들이 버튼 형식으로 뜸 → 클릭 시 위치 입력 화면으로 이동
class SportSelectScreen extends StatelessWidget {
  const SportSelectScreen({super.key});

  /// ② 선호 운동 체크 목록을 바텀시트로 띄운다. [4강 showModalBottomSheet]
  Future<void> _openPicker(BuildContext context) async {
    final app = context.read<AppState>();
    // 바텀시트 안에서만 쓰는 임시 선택값 (완료를 눌러야 AppState에 반영)
    final temp = <String>{...app.selectedSports};

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (sheetContext) {
        // 바텀시트 안의 체크 상태를 바꾸려면 자체 setState가 필요 → StatefulBuilder
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 바텀시트 위쪽 손잡이(handle) 모양
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '선호하는 운동을 모두 골라주세요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 운동이 늘어나도 넘치지 않도록 Flexible + ListView
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final sport in AppState.allSports)
                          CheckboxListTile(
                            // 운동마다 고유 색의 동그라미 아이콘
                            secondary: CircleAvatar(
                              backgroundColor: sportColor(sport).withAlpha(40),
                              child: Icon(
                                sportIcon(sport),
                                color: sportColor(sport),
                              ),
                            ),
                            title: Text(
                              sport,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: sportColor(sport),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            value: temp.contains(sport),
                            onChanged: (checked) => setSheetState(() {
                              checked! ? temp.add(sport) : temp.remove(sport);
                            }),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        // 선택 순서를 allSports 순서로 정렬해서 돌려준다
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          AppState.allSports.where(temp.contains).toList(),
                        ),
                        child: const Text('완료'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (context.mounted && result != null) {
      final ok = await app.setSelectedSports(result);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.members.error ?? '잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

  /// 관심 운동 카드를 누르면 해당 종목의 질문·설정 흐름으로 이동한다.
  void _openSetup(BuildContext context, String sport) {
    context.go('/sports/${AppRoutes.sportId(sport)}/setup');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sports = app.selectedSports;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ───── 인사 문구 ─────
          Text(
            '${app.userName ?? ''}님, 안녕하세요!',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '관심 있는 운동을 선택하고 나에게 맞는 활동 방식을 설정하세요.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // ───── ① 큰 ⊕ 버튼 (그라데이션 배너) ─────
          Material(
            // InkWell 물결 효과가 보이려면 위에 Material이 있어야 한다
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                ),
              ),
              child: InkWell(
                onTap: () => _openPicker(context),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(60),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관심 운동 선택 / 수정',
                              style: text.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '지금 ${sports.length}개 선택됨',
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ───── ③ 선택한 운동들을 2열 버튼으로 ─────
          Expanded(
            child: sports.isEmpty
                ? _EmptyHint(scheme: scheme)
                : GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.95,
                    children: [
                      for (final sport in sports)
                        _SportButton(
                          sport: sport,
                          onTap: () => _openSetup(context, sport),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 운동을 하나도 안 골랐을 때 보여주는 안내
class _EmptyHint extends StatelessWidget {
  final ColorScheme scheme;

  const _EmptyHint({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 72,
            color: scheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '위의 ⊕ 버튼을 눌러\n관심 운동을 골라주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 운동 하나를 나타내는 정사각형 버튼 (재사용 위젯으로 분리)
/// [꾸미기] 운동마다 고유 색 → 연한 배경 + 진한 아이콘 원 + 위치 개수 알약(chip)
class _SportButton extends StatelessWidget {
  final String sport;
  final VoidCallback onTap;

  const _SportButton({required this.sport, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final count = state.locationsOf(sport).length;
    final configured = state.hasPreference(sport);
    final color = sportColor(sport);

    return Material(
      color: color.withAlpha(30), // 운동 색을 아주 연하게 깐 배경
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias, // InkWell 물결이 모서리 밖으로 안 나가게
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(sportIcon(sport), color: Colors.white, size: 30),
              ),
              const Spacer(),
              Text(
                sport,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              // 위치 개수 알약
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: color),
                    const SizedBox(width: 2),
                    Text(
                      configured
                          ? '운동 설정 완료'
                          : (count == 0 ? '눌러서 운동 설정하기' : '저장된 장소 $count곳'),
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
