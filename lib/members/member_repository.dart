import 'dart:convert';

import 'member_models.dart';
import 'member_store.dart';

class MemberRepository {
  MemberRepository({required this.store, PasswordHasher? hasher})
    : hasher = hasher ?? PasswordHasher();
  final MemberStore store;
  final PasswordHasher hasher;
  Map<String, MemberProfile> _profiles = {};
  Map<String, Map<String, dynamic>> _credentials = {};
  String? sessionId;
  bool _remember = false;
  MemberProfile? get current => _profiles[sessionId];
  static final demoProfiles = [
    MemberProfile(
      id: 'demo-basketball',
      email: 'basketball@demo.invalid',
      nickname: '코트메이트',
      isDemo: true,
      onboarding: 'complete',
      sports: const ['농구', '런닝'],
      favorites: const {'농구'},
      common: const {
        'region': '서울 동작구',
        'place': '학교 야외 코트',
        'times': '평일 저녁',
        'purposes': '경기·승부',
        'bio': '함께 패스하고 즐겁게 뛰어요.',
        'gender': '남성',
        'age': '23',
        'height': '180',
      },
      answers: const {
        '농구': {
          'frequency': '주 2회',
          'duration': '90분',
          'skill': '중급',
          'positions': '슈팅가드',
          'playerBackground': '없음',
        },
        '런닝': {
          'frequency': '주 2회',
          'duration': '40분',
          'pace': '6:00',
          'distance': '5km',
          'watch': '없음',
        },
      },
    ),
    MemberProfile(
      id: 'demo-running',
      email: 'running@demo.invalid',
      nickname: '새벽러너',
      isDemo: true,
      onboarding: 'complete',
      sports: const ['런닝'],
      favorites: const {'런닝'},
      common: const {
        'region': '서울 송파구',
        'place': '석촌호수',
        'times': '주말 오전',
        'purposes': '친목·취미',
        'bio': '대화하며 천천히 달릴 친구를 찾아요.',
      },
      answers: const {
        '런닝': {
          'frequency': '주 3회',
          'duration': '40분',
          'pace': '7:00',
          'distance': '5km',
          'watch': 'Apple Watch',
        },
      },
    ),
    MemberProfile(
      id: 'demo-soccer',
      email: 'soccer@demo.invalid',
      nickname: '주말풋살',
      isDemo: true,
      onboarding: 'complete',
      sports: const ['축구'],
      common: const {'region': '서울 마포구', 'times': '주말 오후', 'purposes': '연습·성장'},
      answers: const {
        '축구': {
          'frequency': '주 1회',
          'duration': '120분',
          'skill': '초급',
          'positions': '미드필더',
          'subPosition': '수비수',
          'foot': '오른발',
          'activityType': '풋살',
          'playerBackground': '없음',
        },
      },
    ),
  ];
  Future<void> restore() async {
    final raw = await store.read();
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported member store version');
    }
    final profiles = (j['profiles'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, MemberProfile.fromJson(v as Map<String, dynamic>)),
    );
    final credentials = (j['credentials'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
    );
    final session = j['session'] as String?;
    if (session != null && !profiles.containsKey(session)) {
      throw const FormatException('Invalid session');
    }
    _profiles = profiles;
    _credentials = credentials;
    sessionId = session;
    _remember = session != null;
  }

  Future<void> _commit(
    Map<String, MemberProfile> profiles,
    Map<String, Map<String, dynamic>> credentials,
    String? session,
    bool remember,
  ) async {
    await store.write(
      jsonEncode({
        'version': 1,
        'profiles': profiles.map((k, v) => MapEntry(k, v.toJson())),
        'credentials': credentials,
        'session': remember ? session : null,
      }),
    );
    _profiles = profiles;
    _credentials = credentials;
    sessionId = session;
    _remember = remember;
  }

  void _validateNickname(String nickname, {String? excluding}) {
    final error = MemberValidation.nickname(nickname);
    if (error != null) throw MemberFailure(error, field: 'nickname');
    if (_profiles.values.any(
      (p) =>
          p.id != excluding &&
          p.nickname.toLowerCase() == nickname.trim().toLowerCase(),
    )) {
      throw const MemberFailure('이미 사용 중인 닉네임입니다.', field: 'nickname');
    }
  }

  Future<void> signUp(
    String nickname,
    String email,
    String password,
    bool agreed,
  ) async {
    final normalized = MemberValidation.normalizeEmail(email);
    if (!agreed) {
      throw const MemberFailure('프로토타입 이용 안내를 확인해주세요.', field: 'agreement');
    }
    _validateNickname(nickname);
    final error =
        MemberValidation.email(email) ?? MemberValidation.password(password);
    if (error != null) throw MemberFailure(error);
    if (normalized.endsWith('@demo.invalid') ||
        _profiles.containsKey(normalized)) {
      throw const MemberFailure('이미 사용 중이거나 예약된 이메일입니다.', field: 'email');
    }
    final credential = await hasher.hash(password);
    final member = MemberProfile(
      id: normalized,
      email: normalized,
      nickname: nickname.trim(),
    );
    await _commit(
      {..._profiles, normalized: member},
      {..._credentials, normalized: credential},
      normalized,
      true,
    );
  }

  Future<void> login(String email, String password, bool remember) async {
    final id = MemberValidation.normalizeEmail(email);
    final credential = _credentials[id];
    if (credential == null || !await hasher.verify(password, credential)) {
      throw const MemberFailure('이메일 또는 비밀번호를 확인해주세요.', field: 'password');
    }
    await _commit(_profiles, _credentials, id, remember);
  }

  Future<void> useDemo(String id) async {
    final seed = demoProfiles.where((p) => p.id == id).firstOrNull;
    if (seed == null) throw const MemberFailure('데모 계정을 선택해주세요.');
    await _commit(
      {..._profiles, id: _profiles[id] ?? seed},
      _credentials,
      id,
      true,
    );
  }

  Future<void> save(MemberProfile p) async {
    if (sessionId != p.id) {
      throw const MemberFailure('로그인한 계정이 바뀌었어요. 다시 열어주세요.');
    }
    _validateNickname(p.nickname, excluding: p.id);
    await _commit({..._profiles, p.id: p}, _credentials, sessionId, _remember);
  }

  Future<void> logout() => _commit(_profiles, _credentials, null, false);
}
