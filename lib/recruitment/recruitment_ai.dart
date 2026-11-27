import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'recruitment.dart';

class RecruitmentAi {
  RecruitmentAi({http.Client? client, Uri? baseUrl}) : _client = client ?? http.Client(),
    baseUrl = baseUrl ?? Uri.parse(const String.fromEnvironment('AI_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('AI_BASE_URL')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8787' : 'http://127.0.0.1:8787');
  final http.Client _client;
  final Uri baseUrl;
  Future<RecruitmentDraft> generate(RecruitmentInput input) async {
    try {
      final response = await _client.post(baseUrl.resolve('/api/recruitment/generate'),
        headers: {'Content-Type':'application/json'}, body:jsonEncode(input.toJson()..remove('location'))).timeout(const Duration(seconds:55));
      if (response.statusCode != 200) {
        throw RecruitmentAiFailure(switch(response.statusCode) {
          503 => 'AI 서버 API 키 또는 모델 설정을 확인해주세요.',
          429 => '요청 한도에 도달했어요. 잠시 후 다시 시도해주세요.',
          504 => 'AI 응답 시간이 초과됐어요.',
          400 || 413 => '입력 조건을 확인해주세요.',
          _ => 'AI 모집글을 생성하지 못했어요.',
        });
      }
      final draft = RecruitmentDraft.fromJson(Map<String,dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map));
      if (draft.title.trim().isEmpty || draft.body.trim().isEmpty || draft.title.length > 60 || draft.body.length > 1000 || draft.conditions.length > 12 || draft.conditions.any((c) => c.trim().isEmpty || c.length > 120)) {
        throw const RecruitmentAiFailure('AI 응답 형식이 올바르지 않아요.');
      }
      return draft;
    } on RecruitmentAiFailure { rethrow; }
    on TimeoutException { throw const RecruitmentAiFailure('AI 응답 시간이 초과됐어요.'); }
    catch (_) { throw const RecruitmentAiFailure('AI 서버 연결 또는 응답을 확인해주세요.'); }
  }
  void close() => _client.close();
}
class RecruitmentAiFailure implements Exception {
  const RecruitmentAiFailure(this.message);
  final String message;
}
