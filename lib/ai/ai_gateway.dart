import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiTurn {
  const AiTurn(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
  Map<String, String> toJson() => {
    'role': fromUser ? 'user' : 'assistant',
    'content': text,
  };
}

class AiFailure implements Exception {
  const AiFailure(this.message);
  final String message;
}

abstract interface class AiGateway {
  Future<String> answer(List<AiTurn> history);
  void close();
}

class HttpAiGateway implements AiGateway {
  HttpAiGateway({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 55),
  }) : _client = client ?? http.Client(),
       baseUrl =
           baseUrl ??
           Uri.parse(
             const String.fromEnvironment(
                   'AI_BASE_URL',
                   defaultValue: '',
                 ).isNotEmpty
                 ? const String.fromEnvironment('AI_BASE_URL')
                 : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                 ? 'http://10.0.2.2:8787'
                 : 'http://127.0.0.1:8787',
           );
  final http.Client _client;
  final Uri baseUrl;
  final Duration timeout;
  @override
  Future<String> answer(List<AiTurn> history) async {
    try {
      final response = await _client
          .post(
            baseUrl.resolve('/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': history.map((m) => m.toJson()).toList(),
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AiFailure(switch (response.statusCode) {
          503 => 'AI 서버의 OpenAI API 키 설정이 필요해요. 서버 설정 후 다시 시도해주세요.',
          429 => '요청이 많거나 API 사용 한도에 도달했어요. 잠시 후 다시 시도해주세요.',
          504 => 'AI 응답 시간이 초과됐어요. 다시 시도해주세요.',
          400 || 413 => '질문이 너무 길거나 대화 형식이 올바르지 않아요. 질문을 줄여주세요.',
          _ => 'AI 서버에서 답변을 받지 못했어요. 잠시 후 다시 시도해주세요.',
        });
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text = data is Map ? data['reply'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const AiFailure('빈 답변을 받았어요. 다시 시도해주세요.');
      }
      return text.trim();
    } on AiFailure {
      rethrow;
    } on TimeoutException {
      throw const AiFailure('AI 응답 시간이 초과됐어요. 다시 시도해주세요.');
    } on FormatException {
      throw const AiFailure('서버 응답을 읽을 수 없어요. 서버 설정을 확인해주세요.');
    } catch (_) {
      throw const AiFailure('AI 서버에 연결할 수 없어요. 서버 실행과 연결 주소를 확인해주세요.');
    }
  }

  @override
  void close() => _client.close();
}
