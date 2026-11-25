import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../members/member_models.dart';

const operatorEmail = 'operator@exercise-assist.local';
const operatorId = '__operator__';

abstract interface class AdminGateway {
  Future<String> login(String password);
  Future<void> verify(String token);
  Future<void> logout(String token);
  void close();
}

class HttpAdminGateway implements AdminGateway {
  HttpAdminGateway({http.Client? client, Uri? baseUrl})
    : _client = client ?? http.Client(),
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
  Future<Map<String, dynamic>> _post(
    String action, {
    String? token,
    Map<String, String> body = const {},
  }) async {
    try {
      final response = await _client
          .post(
            baseUrl.resolve('/api/admin/$action'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw MemberFailure(switch (response.statusCode) {
          401 =>
            action == 'login'
                ? '운영자 비밀번호를 확인해주세요.'
                : '운영자 인증이 만료됐어요. 로그아웃 후 다시 로그인해주세요.',
          429 => '로그인 시도가 많아요. 15분 후 다시 시도해주세요.',
          503 => '서버에 운영자 계정이 설정되지 않았어요.',
          _ => '운영자 인증 서버에 연결할 수 없어요.',
        });
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on MemberFailure {
      rethrow;
    } catch (_) {
      throw const MemberFailure('운영자 서버 연결을 확인해주세요. 서버가 실행 중이어야 합니다.');
    }
  }

  @override
  Future<String> login(String password) async {
    final data = await _post(
      'login',
      body: {'email': operatorEmail, 'password': password},
    );
    final token = data['token'];
    if (data['email'] != operatorEmail ||
        token is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const MemberFailure('운영자 인증 응답을 확인하지 못했어요.');
    }
    return token;
  }

  @override
  Future<void> verify(String token) async {
    final data = await _post('session', token: token);
    if (data['authorized'] != true || data['email'] != operatorEmail) {
      throw const MemberFailure('운영자 권한이 필요해요.');
    }
  }

  @override
  Future<void> logout(String token) async {
    await _post('logout', token: token);
  }

  @override
  void close() => _client.close();
}
