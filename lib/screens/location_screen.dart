import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../theme/app_theme.dart';

/// PDF 3페이지 ⑤: 자주 가는 운동 위치 여러 개를 저장 (입력 가능)
/// ⑥ 위치를 고르면 → pop(위치)로 돌아가고, 호출한 쪽에서 운동분석 탭으로 이동시킨다.
class LocationScreen extends StatefulWidget {
  // [4강] 앞 화면에서 생성자로 넘겨받는 데이터
  final String sport;

  const LocationScreen({super.key, required this.sport});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<AppState>().addLocation(widget.sport, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sport = widget.sport; // StatefulWidget에서는 widget.xxx 로 생성자 값을 읽는다
    final locations = context.watch<AppState>().locationsOf(sport);
    final color = sportColor(sport);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Icon(sportIcon(sport), color: color),
            const SizedBox(width: 8),
            Text('$sport 위치', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('자주 가는 $sport 위치를\n입력해주세요.',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('위치를 누르면 해당 위치의 운동 분석으로 이동합니다.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),

            // 위치 입력창 (PDF: 📍 여의도 ....) + 추가 버튼
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: appInputDecoration(context,
                        hint: '예) 여의도 한강공원', icon: Icons.location_on_outlined),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: FilledButton(
                    onPressed: _add,
                    style: FilledButton.styleFrom(
                      backgroundColor: color, // 운동 색으로 버튼 칠하기
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(56, 56),
                    ),
                    child: const Icon(Icons.add_rounded, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 저장된 위치 목록 (1. 영등포 2. 흑석동 3. 당산 ...)
            Expanded(
              child: locations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 72, color: scheme.outlineVariant),
                          const SizedBox(height: 8),
                          Text('아직 저장된 위치가 없어요.',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: locations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final loc = locations[i];
                        return SectionCard(
                          padding: EdgeInsets.zero,
                          // 투명 Material: ListTile 눌림 효과(물결)가 카드 위에 보이도록
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            leading: CircleAvatar(
                              backgroundColor: color.withAlpha(40),
                              foregroundColor: color,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            title: Text(loc,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('눌러서 운동 분석 보기'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: scheme.error),
                              onPressed: () =>
                                  context.read<AppState>().removeLocation(sport, loc),
                            ),
                            // ⑥ 선택한 위치를 결과로 돌려주며 닫기
                            onTap: () => Navigator.pop(context, loc),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
