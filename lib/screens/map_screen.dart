import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../map/location_service.dart';
import '../map/place_sheet.dart';
import '../map/sport_place.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../routing/app_routes.dart';

/// 지도 탭: 종목별 운동 장소를 실제 지도(OpenStreetMap) 위에 보여준다.
///
/// - [8강 packages] flutter_map + latlong2 (API 키가 필요 없는 오픈 지도)
/// - [8강 packages] geolocator 로 "내 위치" (버튼을 눌렀을 때만 권한 요청)
/// - [6강 async]   마커를 누르면 그 좌표의 실시간 날씨를 받아 운동 지수 표시
/// - [5강 state]   저장한 장소는 AppState(Provider)에 넣어 다른 화면과 공유
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  /// 위젯 테스트에서는 네트워크 타일을 끈다. (테스트는 인터넷에 의존하지 않는다)
  static bool showTiles = true;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  String? _sport; // null = 전체
  GeoPoint? _me;
  bool _locating = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  static LatLng _latLng(double lat, double lng) => LatLng(lat, lng);

  double? _distanceTo(SportPlace place) => _me == null
      ? null
      : distanceKm(_me!, GeoPoint(place.latitude, place.longitude));

  Future<void> _locate() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final me = await app.locationService.current();
      if (!mounted) return;
      setState(() => _me = me);
      _map.move(_latLng(me.latitude, me.longitude), 14);
    } on LocationFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _open(SportPlace place) {
    final app = context.read<AppState>();
    _map.move(
      _latLng(place.latitude, place.longitude),
      _map.camera.zoom < 14 ? 14 : _map.camera.zoom,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlaceSheet(
        place: place,
        service: app.weatherService,
        sport: _sport,
        distanceKm: _distanceTo(place),
      ),
    );
  }

  /// 지도에 좌표가 없는(직접 입력한) 장소까지 포함한 "내 장소" 목록.
  void _openSaved() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final app = sheetContext.watch<AppState>();
        final entries = [
          for (final sport in app.selectedSports)
            for (final name in app.locationsOf(sport)) (sport: sport, name: name),
        ];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text('내 운동 장소',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('아직 저장한 장소가 없어요. 지도에서 마커를 눌러 저장해보세요.'),
                ),
              for (final e in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(sportIcon(e.sport), color: sportColor(e.sport)),
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(SportPlaces.byName(e.name) == null
                      ? '${e.sport} · 직접 입력한 장소 (지도 좌표 없음)'
                      : '${e.sport} · 지도에서 보기'),
                  onTap: () {
                    final place = SportPlaces.byName(e.name);
                    Navigator.of(sheetContext).pop();
                    if (place != null) _open(place);
                  },
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  final sport = _sport ??
                      (app.selectedSports.isNotEmpty ? app.selectedSports.first : null);
                  if (sport == null) {
                    context.go(AppRoutes.sports);
                  } else {
                    context.go('/sports/${AppRoutes.sportId(sport)}/locations');
                  }
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('장소 직접 입력하기'),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSaved(AppState app, SportPlace place) =>
      place.sports.any((s) => app.locationsOf(s).contains(place.name));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final places = SportPlaces.visible(sport: _sport, origin: _me);
    final savedCount = [
      for (final sport in app.selectedSports) ...app.locationsOf(sport),
    ].length;
    // 내 관심 종목을 앞에 두고, 나머지 지도 지원 종목을 뒤에 둔다.
    final chips = [
      ...app.selectedSports.where(SportPlaces.mapSports.contains),
      ...SportPlaces.mapSports.where((s) => !app.selectedSports.contains(s)),
    ];

    return Column(
      children: [
        // ── 종목 필터 ──
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _sport == null,
                onSelected: (_) => setState(() => _sport = null),
              ),
              for (final sport in chips) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: Icon(sportIcon(sport), size: 18, color: sportColor(sport)),
                  label: Text(sport),
                  selected: _sport == sport,
                  onSelected: (_) => setState(() => _sport = sport),
                ),
              ],
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.bookmark_outline, size: 18),
                label: Text('내 장소 $savedCount'),
                onPressed: _openSaved,
              ),
            ],
          ),
        ),

        // ── 지도 + 오버레이 ──
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _latLng(
                    SportPlaces.defaultCenter.latitude,
                    SportPlaces.defaultCenter.longitude,
                  ),
                  initialZoom: 12,
                  minZoom: 6,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  if (MapScreen.showTiles)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.exercise_assist',
                    ),
                  MarkerLayer(
                    markers: [
                      for (final place in places)
                        Marker(
                          point: _latLng(place.latitude, place.longitude),
                          width: 46,
                          height: 46,
                          child: _PlaceMarker(
                            key: ValueKey('marker-${place.id}'),
                            sport: _sport ?? place.sports.first,
                            saved: _isSaved(app, place),
                            onTap: () => _open(place),
                          ),
                        ),
                      if (_me != null)
                        Marker(
                          point: _latLng(_me!.latitude, _me!.longitude),
                          width: 26,
                          height: 26,
                          child: const _MyLocationDot(),
                        ),
                    ],
                  ),
                  if (MapScreen.showTiles)
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                ],
              ),

              // 내 위치 버튼
              Positioned(
                right: 14,
                top: 12,
                child: FloatingActionButton.small(
                  heroTag: 'map-locate',
                  tooltip: '내 위치',
                  onPressed: _locating ? null : _locate,
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),

              // 하단 장소 카드 (내 위치가 있으면 가까운 순)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SizedBox(
                  height: 96,
                  child: places.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: places.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final place = places[i];
                            final distance = _distanceTo(place);
                            return _PlaceCard(
                              place: place,
                              distance: distance,
                              saved: _isSaved(app, place),
                              onTap: () => _open(place),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Text(
            '${places.length}곳 · 장소 좌표는 대략적인 위치예요.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({
    super.key,
    required this.sport,
    required this.saved,
    required this.onTap,
  });
  final String sport;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sportColor(sport);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(sportIcon(sport), color: Colors.white, size: 22),
          ),
          if (saved)
            const Positioned(
              right: -2,
              top: -2,
              child: Icon(Icons.star_rounded, color: Color(0xFFFFC21A), size: 18),
            ),
        ],
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F80ED),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
      );
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.distance,
    required this.saved,
    required this.onTap,
  });
  final SportPlace place;
  final double? distance;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      child: Material(
        color: scheme.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (saved)
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC21A), size: 18),
                ]),
                const SizedBox(height: 2),
                Text(
                  distance == null
                      ? '${place.area} · ${place.kind}'
                      : '${formatDistance(distance!)} · ${place.kind}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                Row(children: [
                  for (final sport in place.sports)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(sportIcon(sport), size: 18, color: sportColor(sport)),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
