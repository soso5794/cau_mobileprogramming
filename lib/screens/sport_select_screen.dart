import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../routing/app_routes.dart';
import '../models/sport_icons.dart';
import '../theme/app_theme.dart';
import 'sport_picker_sheet.dart';

/// PDF 3페이지: 선호 운동 선택 화면 (하단 탭 0번)
/// ① 로그인 후 등장, 큰 ⊕ 버튼
/// ② ⊕ 누르면 선호 운동 여러 개 선택 가능 (체크 형식)
/// ③ 선택한 운동들이 버튼 형식으로 뜸 → 클릭 시 위치 입력 화면으로 이동
class SportSelectScreen extends StatelessWidget {
  const SportSelectScreen({super.key});

  /// ② 선호 운동 체크 목록을 바텀시트로 띄운다. [4강 showModalBottomSheet]
  Future<void> _openPicker(BuildContext context) async {
    final app = context.read<AppState>();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SportPickerSheet(initialSelection: app.selectedSports),
    );

    if (context.mounted && result != null) app.setSelectedSports(result);
  }

  /// 종목을 URL 매개변수로 전달한다. 상세 뒤로 가기는 운동 선택으로 돌아온다.
  void _openLocation(BuildContext context, String sport) {
    context.goNamed(
      AppRoutes.locationsName,
      pathParameters: {'sport': AppRoutes.sportId(sport)},
    );
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
            '좋아하는 운동을 고르고 자주 가는 장소를 등록하세요.',
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
                              '선호 운동 추가 / 수정',
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
                          onTap: () => _openLocation(context, sport),
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
            '위의 ⊕ 버튼을 눌러\n선호 운동을 골라주세요.',
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
    final count = context.watch<AppState>().locationsOf(sport).length;
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
                      count == 0 ? '위치 등록하기' : '저장된 위치 $count곳',
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
