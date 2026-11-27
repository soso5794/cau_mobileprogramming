import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'recruitment_location.dart';

class PlaceSearchService {
  PlaceSearchService({http.Client? client, Uri? baseUrl}) : _client = client ?? http.Client(),
    _base = baseUrl ?? Uri.parse(const String.fromEnvironment('AI_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('AI_BASE_URL')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8787' : 'http://127.0.0.1:8787');
  final http.Client _client;
  final Uri _base;
  Future<List<RecruitmentLocation>> search(String query) async {
    final q = query.trim();
    if (q.length < 2 || q.length > 120) throw const PlaceSearchFailure('검색어를 2~120자로 입력해주세요.');
    try {
      final response = await _client.post(_base.resolve('/api/places/search'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'query': q}))
        .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw PlaceSearchFailure(switch (response.statusCode) {
          503 => '장소 검색 키(GEOAPIFY_API_KEY)를 서버에 설정해주세요. 지도에서 직접 선택할 수도 있어요.',
          429 => '검색 요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
          _ => '장소 검색에 실패했어요. 다시 시도해주세요.',
        });
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      return (json['results'] as List).map((v) => RecruitmentLocation.fromJson(Map<String,dynamic>.from(v as Map)))
        .where((v) => v.isValid).toList();
    } on PlaceSearchFailure { rethrow; }
    catch (_) { throw const PlaceSearchFailure('장소 검색 서버에 연결할 수 없어요. 서버를 실행하거나 지도에서 직접 선택해주세요.'); }
  }
  void close() => _client.close();
}
class PlaceSearchFailure implements Exception {
  const PlaceSearchFailure(this.message);
  final String message;
}
