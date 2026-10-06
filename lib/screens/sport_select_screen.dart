import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import 'location_screen.dart';

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
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('선호하는 운동을 모두 골라주세요',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  // 운동이 늘어나도 넘치지 않도록 Flexible + ListView
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final sport in AppState.allSports)
                          CheckboxListTile(
                            secondary: Icon(sportIcon(sport)),
                            title: Text(sport),
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

    if (result != null) app.setSelectedSports(result);
  }

  /// ③ 운동 버튼 클릭 → 위치 입력 화면. 위치를 고르고 돌아오면 ⑥ 운동분석 탭으로 자동 이동.
  Future<void> _openLocation(BuildContext context, String sport) async {
    final app = context.read<AppState>();
    // [4강] 생성자로 데이터 전달(sport) + await로 결과 받기(선택한 위치)
    final location = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => LocationScreen(sport: sport)),
    );
    if (location != null) {
      app.selectTarget(sport, location);
      app.goToTab(2); // 운동분석 탭
    }
  }

  @override
  Widget build(BuildContext context) {
    final sports = context.watch<AppState>().selectedSports;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ① 큰 ⊕ 버튼
          SizedBox(
            width: double.infinity,
            height: 100,
            child: OutlinedButton(
              onPressed: () => _openPicker(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 36),
                  SizedBox(height: 4),
                  Text('선호 운동 추가 / 수정'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ③ 선택한 운동들을 2열 버튼으로
          Expanded(
            child: sports.isEmpty
                ? const Center(child: Text('⊕ 버튼을 눌러 선호 운동을 골라주세요.'))
                : GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
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

/// 운동 하나를 나타내는 정사각형 버튼 (재사용 위젯으로 분리)
class _SportButton extends StatelessWidget {
  final String sport;
  final VoidCallback onTap;

  const _SportButton({required this.sport, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AppState>().locationsOf(sport).length;
    return Card(
      clipBehavior: Clip.antiAlias, // InkWell 물결이 카드 모서리 밖으로 안 나가게
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(sportIcon(sport), size: 48),
            const SizedBox(height: 8),
            Text(sport, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('저장된 위치 $count곳', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
