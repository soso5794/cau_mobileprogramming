import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../map/location_service.dart';
import '../map/place_sheet.dart';
import '../map/recruitment_pins.dart';
import '../map/sport_place.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../recruitment/place_search_service.dart';
import '../recruitment/recruitment_location.dart';
import '../routing/app_routes.dart';

/// 지도 탭: 종목별 운동 장소를 실제 지도(OpenStreetMap) 위에 보여준다.
///
/// - [8강 packages] flutter_map + latlong2 (API 키가 필요 없는 오픈 지도)
/// - [8강 packages] geolocator 로 "내 위치" (버튼을 눌렀을 때만 권한 요청)
/// - [6강 async]   마커를 누르면 그 좌표의 실시간 날씨를 받아 운동 지수 표시
/// - [5강 state]   저장한 장소는 AppState(Provider)에 넣어 다른 화면과 공유
/// - 장소·주소 검색: 모집글 장소 선택과 같은 PlaceSearchService
///   (Flutter → 로컬 Node 서버 /api/places/search → Geoapify, 키는 server/.env)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.searchService});

  /// 테스트에서 가짜 검색 서비스를 넣기 위한 자리. 평소에는 null → 기본 서비스.
  final PlaceSearchService? searchService;

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
  bool _showPosts = true; // 모집글 핀 표시 여부

  // ── 장소·주소 검색 상태 ──
  final _query = TextEditingController();
  late final PlaceSearchService _search =
      widget.searchService ?? PlaceSearchService();
  List<RecruitmentLocation> _results = [];
  RecruitmentLocation? _picked; // 검색으로 고른 장소 (빨간 핀)
  final _searchedByName = <String, RecruitmentLocation>{}; // 내 장소에서 다시 찾기용
  bool _searching = false;
  String? _searchMessage;

  @override
  void dispose() {
    _map.dispose();
    _query.dispose();
    if (widget.searchService == null) _search.close();
    super.dispose();
  }

  Future<void> _runSearch() async {
    if (_searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchMessage = null;
      _results = [];
    });
    try {
      final results = await _search.search(_query.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _searchMessage = '검색 결과가 없어요. 다른 장소명이나 주소로 검색해보세요.';
      });
    } on PlaceSearchFailure catch (e) {
      if (mounted) setState(() => _searchMessage = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _query.clear();
    setState(() {
      _results = [];
      _picked = null;
      _searchMessage = null;
    });
  }

  /// 검색 결과 선택 → 지도 이동 + 빨간 핀. 날씨는 핀을 누르면 기존 시트로 본다.
  void _pickResult(RecruitmentLocation location) {
    setState(() {
      _picked = location;
      _results = [];
      _searchedByName[location.name] = location;
    });
    _map.move(_latLng(location.latitude, location.longitude), 16);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${location.name} · 빨간 핀을 누르면 날씨와 운동 지수를 볼 수 있어요.'),
        duration: const Duration(seconds: 3),
      ));
  }

  /// 검색한 장소를 기존 PlaceSheet(날씨·지수·즐겨찾기)에서 쓸 수 있게 변환.
  SportPlace _asSportPlace(RecruitmentLocation location) => SportPlace(
        id: 'search',
        name: location.name,
        area: location.address.isEmpty ? '검색한 장소' : location.address,
        latitude: location.latitude,
        longitude: location.longitude,
        sports: SportPlaces.mapSports,
        kind: '검색 결과',
      );

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
                  child: Text(
                    '아직 저장한 장소가 없어요. 지도에서 마커를 눌러 저장하거나, '
                    '주간 계획이나 운동 분석에서 자주 가는 위치를 등록하면 여기에 표시돼요.',
                  ),
                ),
              for (final e in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(sportIcon(e.sport), color: sportColor(e.sport)),
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    SportPlaces.byName(e.name) != null || _searchedByName.containsKey(e.name)
                        ? '${e.sport} · 지도에서 보기'
                        : '${e.sport} · 운동 분석 보기',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    final place = SportPlaces.byName(e.name);
                    final searched = _searchedByName[e.name];
                    if (place != null) {
                      _open(place);
                    } else if (searched != null) {
                      _pickResult(searched);
                      _open(_asSportPlace(searched));
                    } else {
                      // 좌표가 없는 장소는 기존처럼 운동 분석 화면으로.
                      app.selectTarget(e.sport, e.name);
                      context.go(AppRoutes.analysisPage);
                    }
                  },
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.go(AppRoutes.planPage);
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('주간 계획에서 위치 등록'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 모집글 핀을 누르면: 그 장소의 모집글 목록 → 누르면 기존 모집글 상세 화면.
  void _openPosts(RecruitmentPin pin) {
    _map.move(
      _latLng(pin.latitude, pin.longitude),
      _map.camera.zoom < 15 ? 15 : _map.camera.zoom,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(pin.place,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('모집 중인 글 ${pin.posts.length}개',
                  style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              for (final post in pin.posts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: ValueKey('map-post-${post.id}'),
                    leading: Icon(sportIcon(post.sport), color: sportColor(post.sport)),
                    title: Text(post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${post.time}\n${post.people} · ${post.sourceLabel}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/community/posts/${post.id}');
                    },
                  ),
                ),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _open(SportPlace(
                        id: 'posts',
                        name: pin.place,
                        area: '모집글 장소',
                        latitude: pin.latitude,
                        longitude: pin.longitude,
                        sports: SportPlaces.mapSports.contains(pin.mainSport)
                            ? [pin.mainSport]
                            : SportPlaces.mapSports,
                        kind: '모집 장소',
                      ));
                    },
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text('이곳 날씨'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push(AppRoutes.recruitmentCreate(pin.mainSport));
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('모집글 쓰기'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSaved(AppState app, SportPlace place) =>
      place.sports.any((s) => app.locationsOf(s).contains(place.name));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final places = SportPlaces.visible(sport: _sport, origin: _me);
    final allPosts = app.members.operations.posts;
    final pins = recruitmentPins(allPosts, sport: _sport);
    final pinPostCount = pins.fold(0, (sum, p) => sum + p.posts.length);
    final unmapped = unmappedRecruitmentCount(allPosts, sport: _sport);
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
        // ── 장소·주소 검색 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('map-search-field'),
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: '장소명 또는 주소 검색',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: _query.text.isEmpty && _picked == null
                        ? null
                        : IconButton(
                            tooltip: '검색 지우기',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('map-search-button'),
                onPressed: _searching ? null : _runSearch,
                child: const Text('검색'),
              ),
            ],
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        if (_searchMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Text(
              _searchMessage!,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ),

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
              FilterChip(
                key: const ValueKey('map-posts-toggle'),
                avatar: const Icon(Icons.campaign_outlined, size: 18),
                label: Text('모집글 $pinPostCount'),
                selected: _showPosts,
                showCheckmark: false,
                onSelected: (on) => setState(() => _showPosts = on),
              ),
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
                      if (_showPosts)
                        for (final pin in pins)
                          Marker(
                            point: _latLng(pin.latitude, pin.longitude),
                            width: 78,
                            height: 34,
                            alignment: Alignment.topCenter,
                            child: _PostPinMarker(
                              key: ValueKey(
                                  'post-pin-${pin.latitude.toStringAsFixed(4)},${pin.longitude.toStringAsFixed(4)}'),
                              pin: pin,
                              onTap: () => _openPosts(pin),
                            ),
                          ),
                      if (_picked != null)
                        Marker(
                          point: _latLng(_picked!.latitude, _picked!.longitude),
                          width: 46,
                          height: 46,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            key: const ValueKey('marker-search'),
                            onTap: () => _open(_asSportPlace(_picked!)),
                            child: const Icon(Icons.location_on,
                                size: 46, color: Color(0xFFE53935)),
                          ),
                        ),
                    ],
                  ),
                  if (MapScreen.showTiles)
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                        TextSourceAttribution('검색: Geoapify'),
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

              // 검색 결과 목록 (지도 위에 겹쳐 표시)
              if (_results.isNotEmpty)
                Positioned(
                  left: 14,
                  right: 14,
                  top: 8,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    color: scheme.surface,
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          ListTile(
                            dense: true,
                            title: Text('검색 결과 ${_results.length}곳',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            trailing: IconButton(
                              tooltip: '결과 닫기',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _results = []),
                            ),
                          ),
                          for (final (i, r) in _results.indexed)
                            ListTile(
                              key: ValueKey('search-result-$i'),
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(r.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: r.address.isEmpty
                                  ? null
                                  : Text(r.address,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => _pickResult(r),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Text(
            [
              '운동 장소 ${places.length}곳',
              if (_showPosts) '모집글 $pinPostCount개',
              if (_showPosts && unmapped > 0) '지도 위치 없는 모집글 $unmapped개',
            ].join(' · '),
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

/// 알바몬식 말풍선 핀: 종목 아이콘 + "모집 n".
class _PostPinMarker extends StatelessWidget {
  const _PostPinMarker({super.key, required this.pin, required this.onTap});
  final RecruitmentPin pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sportColor(pin.mainSport);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(sportIcon(pin.mainSport), size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '모집 ${pin.posts.length}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
