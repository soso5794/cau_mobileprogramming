import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text('$sport 위치')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 위치 검색/입력창 (PDF: 📍 여의도 ....)
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on_outlined),
                hintText: '예) 여의도 한강공원',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _add),
              ),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 24),
            Text('자주 가는 $sport 위치를 입력해주세요.',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('위치를 누르면 해당 위치의 운동 분석으로 이동합니다.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            // 저장된 위치 목록 (1. 영등포 2. 흑석동 3. 당산 ...)
            Expanded(
              child: locations.isEmpty
                  ? const Center(child: Text('아직 저장된 위치가 없어요.'))
                  : Card(
                      child: ListView.separated(
                        itemCount: locations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final loc = locations[i];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text(loc),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => context
                                  .read<AppState>()
                                  .removeLocation(sport, loc),
                            ),
                            // ⑥ 선택한 위치를 결과로 돌려주며 닫기
                            onTap: () => Navigator.pop(context, loc),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
