import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class MemberStore {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesMemberStore implements MemberStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  static const key = 'exercise_assist_members_v1';
  @override
  Future<String?> read() => _prefs.getString(key);
  @override
  Future<void> write(String value) => _prefs.setString(key, value);
}

class MemoryMemberStore implements MemberStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class PasswordHasher {
  PasswordHasher({this.iterations = 600000});
  final int iterations;
  Future<String> derive(String password, List<int> salt, int rounds) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return base64Encode(await key.extractBytes());
  }

  Future<Map<String, Object>> hash(String password) async {
    final rnd = Random.secure();
    final salt = List.generate(16, (_) => rnd.nextInt(256));
    return {
      'salt': base64Encode(salt),
      'rounds': iterations,
      'hash': await derive(password, salt, iterations),
    };
  }

  Future<bool> verify(String password, Map<String, dynamic> stored) async {
    final candidate = await derive(
      password,
      base64Decode(stored['salt'] as String),
      stored['rounds'] as int,
    );
    final expected = stored['hash'] as String;
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }
}
