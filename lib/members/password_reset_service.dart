import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'member_models.dart';

abstract interface class PasswordResetService {
  Future<String> request(String email);
  Future<void> verify(String email, String challengeId, String code);
  void close();
}

class HttpPasswordResetService implements PasswordResetService {
  HttpPasswordResetService({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 40),
  }) : _client = client ?? http.Client(),
       baseUrl =
           baseUrl ??
           Uri.parse(
             const String.fromEnvironment('ACCOUNT_BASE_URL').isNotEmpty
                 ? const String.fromEnvironment('ACCOUNT_BASE_URL')
                 : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                 ? 'http://10.0.2.2:8787'
                 : 'http://127.0.0.1:8787',
           );
  final http.Client _client;
  final Uri baseUrl;
  final Duration timeout;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    try {
      final response = await _client
          .post(
            baseUrl.resolve(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200) {
        final code = data is Map ? data['error'] : null;
        throw MemberFailure(switch (code) {
          'MAIL_NOT_CONFIGURED' =>
            '인증메일 발송 설정이 아직 준비되지 않았어요. 서버의 SMTP 설정 후 다시 시도해주세요.',
          'MAIL_DELIVERY_FAILED' =>
            '인증메일을 발송하지 못했어요. 이메일 주소와 서버 발송 설정을 확인하고 1분 후 다시 요청해주세요.',
          'RESET_RATE_LIMITED' =>
            '인증 요청 횟수를 초과했어요. 재발송은 1분 후, 시간당 한도 초과 시 1시간 후 시도해주세요.',
          'RESET_INVALID_OR_EXPIRED' =>
            '인증번호가 틀렸거나 만료·사용됐어요. 번호를 확인하거나 새 인증번호를 요청해주세요.',
          'INVALID_EMAIL' => '이메일 주소를 확인해주세요.',
          _ => '인증 서버에서 요청을 처리하지 못했어요. 다시 시도해주세요.',
        });
      }
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on MemberFailure {
      rethrow;
    } on TimeoutException {
      throw const MemberFailure(
        '인증 서버 응답이 늦어요. 메일이 도착해도 새 요청이 필요할 수 있어요. 잠시 후 다시 시도해주세요.',
      );
    } on FormatException {
      throw const MemberFailure('인증 서버 응답을 확인할 수 없어요. 다시 요청해주세요.');
    } catch (_) {
      throw const MemberFailure('인증 서버에 연결할 수 없어요. 서버 실행과 네트워크 연결을 확인해주세요.');
    }
  }

  @override
  Future<String> request(String email) async {
    final data = await _post('/api/password-reset/request', {'email': email});
    final id = data['challengeId'];
    if (id is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const MemberFailure('인증 요청을 확인할 수 없어요. 다시 요청해주세요.');
    }
    return id;
  }

  @override
  Future<void> verify(String email, String challengeId, String code) async {
    final data = await _post('/api/password-reset/verify', {
      'email': email,
      'challengeId': challengeId,
      'code': code,
    });
    if (data['verified'] != true ||
        data['email'] != email ||
        data['challengeId'] != challengeId) {
      throw const MemberFailure('이 계정의 이메일 인증을 확인하지 못했어요. 다시 요청해주세요.');
    }
  }

  @override
  void close() => _client.close();
}
