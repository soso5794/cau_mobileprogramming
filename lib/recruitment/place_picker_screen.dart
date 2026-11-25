import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'place_search_service.dart';
import 'recruitment_location.dart';

class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({super.key, this.initial, this.initialName = '', this.service});
  final RecruitmentLocation? initial;
  final String initialName;
  final PlaceSearchService? service;
  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _query = TextEditingController();
  late final _name = TextEditingController(text: widget.initial?.name ?? widget.initialName);
  final _map = MapController();
  late final _searchService = widget.service ?? PlaceSearchService();
  late LatLng? _pin = widget.initial == null ? null : LatLng(widget.initial!.latitude, widget.initial!.longitude);
  late String _address = widget.initial?.address ?? '';
  List<RecruitmentLocation> _results = [];
  bool _busy = false, _ready = false;
  String? _message;
  static const _tileUrl = String.fromEnvironment('RECRUITMENT_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  @override
  void dispose() {
    _query.dispose(); _name.dispose(); _map.dispose();
    if (widget.service == null) _searchService.close();
    super.dispose();
  }
  Future<void> _search() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _message = null; _results = []; });
    try {
      final results = await _searchService.search(_query.text);
      if (!mounted) return;
      setState(() { _results = results; if (results.isEmpty) _message = '검색 결과가 없어요. 주소를 바꾸거나 지도에서 직접 선택해주세요.'; });
    } on PlaceSearchFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally { if (mounted) setState(() => _busy = false); }
  }
  void _pickResult(RecruitmentLocation location) {
    final point = LatLng(location.latitude, location.longitude);
    setState(() { _pin = point; _name.text = location.name; _address = location.address; _results = []; _message = null; });
    if (_ready) _map.move(point, 16);
  }
  void _pickPin(LatLng point) {
    // Moving a pin must invalidate any old geocoded address and name.
    setState(() { _pin = point; _address = ''; _name.clear(); _results = []; _message = null; });
  }
  void _confirm() {
    final pin = _pin;
    if (pin == null) return;
    final location = RecruitmentLocation(name: _name.text.trim(), address: _address, latitude: pin.latitude, longitude: pin.longitude);
    if (!location.isValid) {
      setState(() => _message = '장소명과 지도 위치를 확인해주세요.'); return;
    }
    Navigator.of(context).pop(location);
  }
  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    return Scaffold(
      appBar: AppBar(title: const Text('운동 장소 선택')),
      body: SafeArea(child: SingleChildScrollView(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [
          Expanded(child: TextField(controller: _query, textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '장소명 또는 주소 검색'))),
          const SizedBox(width: 8), FilledButton(onPressed: _busy ? null : _search, child: const Text('검색')),
        ])),
        if (_busy) const LinearProgressIndicator(),
        if (_results.isNotEmpty) SizedBox(height: 144, child: ListView.builder(itemCount: _results.length, itemBuilder: (_, i) {
          final r = _results[i];
          return ListTile(dense: true, leading: const Icon(Icons.place_outlined), title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(r.address, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _pickResult(r));
        })),
        SizedBox(height: 360, child: FlutterMap(mapController: _map, options: MapOptions(
          initialCenter: widget.initial == null ? const LatLng(37.5665,126.9780) : LatLng(widget.initial!.latitude,widget.initial!.longitude),
          initialZoom: widget.initial == null ? 12 : 16, minZoom: 3, maxZoom: 19,
          onMapReady: () { _ready = true; }, onTap: (_, point) => _pickPin(point)), children: [
          TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'com.cau.exercise_assist', maxNativeZoom: 19),
          if (pin != null) MarkerLayer(markers: [Marker(point: pin, width: 42, height: 42, child: const Icon(Icons.location_on, size: 42, color: Colors.red))]),
          const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(pin == null ? '지도를 확대하거나 이동한 뒤 원하는 위치를 눌러주세요.' : '선택한 좌표: ${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}', style: Theme.of(context).textTheme.bodySmall),
          if (_address.isNotEmpty) Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis),
          TextField(controller: _name, maxLength: 120, decoration: const InputDecoration(labelText: '모집글에 표시할 장소명', hintText: '예: 중앙대학교 농구장'), onChanged: (_) => setState(() {})),
          if (_message != null) Text(_message!, maxLines: 3, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const Text('지도: OpenStreetMap · 검색: Geoapify', style: TextStyle(fontSize: 11)),
          const SizedBox(height: 6), FilledButton(onPressed: pin == null || _name.text.trim().isEmpty ? null : _confirm, child: const Text('이 장소로 설정하기')),
        ])),
      ]))),
    );
  }
}
