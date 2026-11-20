import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final entries = <({String sport, String location})>[];
    for (final sport in app.selectedSports) {
      for (final location in app.locationsOf(sport)) {
        entries.add((sport: sport, location: location));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        const Text('운동 장소 지도', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('자주 가는 장소를 종목별로 모아봤어요.', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 17),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3E5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD6E6D1)),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.map_outlined, size: 48, color: Color(0xFF075B3D)),
            SizedBox(height: 8),
            Text('내 운동 장소', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF075B3D))),
            SizedBox(height: 4),
            Text('저장한 장소 목록을 확인할 수 있어요.', style: TextStyle(fontSize: 12, color: Color(0xFF526354))),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Text('저장된 장소', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          Text('${entries.length}곳', style: const TextStyle(color: Color(0xFF075B3D), fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          SectionCard(child: Column(children: [
            Icon(Icons.add_location_alt_outlined, size: 42, color: scheme.outline),
            const SizedBox(height: 8),
            const Text('아직 저장한 운동 장소가 없어요.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text('홈에서 운동을 선택하고 설정하면 장소가 여기에 표시돼요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            FilledButton(onPressed: () => context.go(AppRoutes.sports), child: const Text('홈으로 이동')),
          ]))
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SectionCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: sportColor(entry.sport).withAlpha(30), child: Icon(sportIcon(entry.sport), color: sportColor(entry.sport))),
                  title: Text(entry.location, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(entry.sport),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    app.selectTarget(entry.sport, entry.location);
                    context.go(AppRoutes.analysisPage);
                  },
                ),
              ),
            ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            final sport = app.selectedSports.isNotEmpty ? app.selectedSports.first : null;
            if (sport == null) {
              context.go(AppRoutes.sports);
              return;
            }
            context.go('/sports/${AppRoutes.sportId(sport)}/locations');
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('운동 장소 추가'),
        ),
        const SizedBox(height: 8),
        Text('실제 지도 타일 및 현재 위치 기능은 지도 API 연동이 필요해요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
