import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';

/// 검색·선택은 로컬 초안이며 '완료'를 눌러야 부모 화면에 반영된다.
class SportPickerSheet extends StatefulWidget {
  const SportPickerSheet({super.key, required this.initialSelection});
  final List<String> initialSelection;

  @override
  State<SportPickerSheet> createState() => _SportPickerSheetState();
}

class _SportPickerSheetState extends State<SportPickerSheet> {
  final _search = TextEditingController();
  late final Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final sports = AppState.allSports
        .where((sport) => sport.contains(query))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '선호 운동 선택 · ${_selection.length}개',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sport-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '종목 검색',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: '검색 지우기',
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.clear),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: sports.isEmpty
                    ? const Center(child: Text('검색 결과가 없어요.'))
                    : ListView(
                        children: [
                          for (final sport in sports)
                            CheckboxListTile(
                              key: Key('pick-$sport'),
                              secondary: Icon(
                                sportIcon(sport),
                                color: sportColor(sport),
                              ),
                              title: Text(sport),
                              value: _selection.contains(sport),
                              onChanged: (checked) => setState(() {
                                checked == true
                                    ? _selection.add(sport)
                                    : _selection.remove(sport);
                              }),
                            ),
                        ],
                      ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    key: const Key('save-sports'),
                    onPressed: () => Navigator.pop(
                      context,
                      AppState.allSports.where(_selection.contains).toList(),
                    ),
                    child: const Text('완료'),
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
