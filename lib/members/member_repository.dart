import 'dart:convert';
import '../admin/admin_gateway.dart';
import '../admin/operations_data.dart';
import '../community/community_data.dart';
import '../calendar/workout_event.dart';
import '../ranking/ranking_data.dart';

import 'member_models.dart';
import 'member_store.dart';
import 'password_reset_service.dart';

class MemberRepository {
  MemberRepository({
    required this.store,
    PasswordHasher? hasher,
    PasswordResetService? passwordReset,
    AdminGateway? adminGateway,
  }) : hasher = hasher ?? PasswordHasher(),
       passwordReset = passwordReset ?? HttpPasswordResetService(),
       adminGateway = adminGateway ?? HttpAdminGateway();
  final AdminGateway adminGateway;
  String? _operatorToken;
  bool get isOperator => sessionId == operatorId && _operatorToken != null;
  OperationsData _operations = OperationsData();
  OperationsData get operations => _operations;
  List<MemberProfile> get managedMembers =>
      isOperator ? List.unmodifiable(_profiles.values) : const [];
  final PasswordResetService passwordReset;
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
    _operations = j['operations'] is Map
        ? OperationsData.fromJson(
            Map<String, dynamic>.from(j['operations'] as Map),
          )
        : OperationsData();
    // Operator sessions are issued by the server and never restored from local data.
    sessionId = session == operatorId ? null : session;
    _remember = sessionId != null;
    _operatorToken = null;
  }

  Future<void> _commit(
    Map<String, MemberProfile> profiles,
    Map<String, Map<String, dynamic>> credentials,
    String? session,
    bool remember, {
    OperationsData? operations,
  }) async {
    await store.write(
      jsonEncode({
        'version': 1,
        'profiles': profiles.map((k, v) => MapEntry(k, v.toJson())),
        'credentials': credentials,
        'session': remember && session != operatorId ? session : null,
        'operations': (operations ?? _operations).toJson(),
      }),
    );
    _profiles = profiles;
    _credentials = credentials;
    _operations = operations ?? _operations;
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
    if (normalized == operatorEmail ||
        normalized.endsWith('@demo.invalid') ||
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
    if (id == operatorEmail) {
      await loginOperator(password);
      return;
    }
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

  String _resetAccount(String email) {
    final id = MemberValidation.normalizeEmail(email);
    final error = MemberValidation.email(email);
    if (error != null) throw MemberFailure(error);
    if (!_credentials.containsKey(id) || _profiles[id]?.isDemo != false) {
      throw const MemberFailure(
        '이 기기에 저장된 계정을 찾지 못했어요. 가입했던 브라우저·기기에서 시도해주세요.',
      );
    }
    return id;
  }

  Future<String> requestPasswordReset(String email) async =>
      passwordReset.request(_resetAccount(email));

  Future<void> resetPassword(
    String email,
    String challengeId,
    String code,
    String password,
  ) async {
    final id = _resetAccount(email);
    final error = MemberValidation.password(password);
    if (error != null) throw MemberFailure(error);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const MemberFailure('인증번호 6자리를 입력해주세요.');
    }
    // Prepare before consuming the one-time code. Never mutate on failed verification.
    final credential = await hasher.hash(password);
    await passwordReset.verify(id, challengeId, code);
    try {
      await _commit(_profiles, {..._credentials, id: credential}, null, false);
    } catch (_) {
      throw const MemberFailure(
        '비밀번호를 저장하지 못했어요. 기존 비밀번호는 유지돼요. 새 인증번호를 요청한 뒤 다시 시도해주세요.',
      );
    }
  }

  Future<void> loginOperator(String password) async {
    final token = await adminGateway.login(password);
    try {
      final profile =
          _profiles[operatorId] ??
          MemberProfile(
            id: operatorId,
            email: operatorEmail,
            nickname: '운영자',
            onboarding: 'deferred',
          );
      await _commit(
        {..._profiles, operatorId: profile},
        _credentials,
        operatorId,
        false,
      );
      _operatorToken = token;
    } catch (_) {
      try {
        await adminGateway.logout(token);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _authorizeOperator() async {
    final token = _operatorToken;
    if (!isOperator || token == null) {
      throw const MemberFailure('운영자 권한이 필요해요.');
    }
    await adminGateway.verify(token);
    if (!isOperator || _operatorToken != token) {
      throw const MemberFailure('운영자 계정이 바뀌었어요. 다시 로그인해주세요.');
    }
  }

  Future<void> saveManagedProfile(MemberProfile p) async {
    await _authorizeOperator();
    final original = _profiles[p.id];
    if (original == null ||
        original.email != p.email ||
        original.isDemo != p.isDemo) {
      throw const MemberFailure('회원 정보를 다시 확인해주세요.');
    }
    _validateNickname(p.nickname, excluding: p.id);
    await _commit(
      {..._profiles, p.id: p.copyWith(events: original.events)},
      _credentials,
      sessionId,
      false,
      operations: _operations.changed('회원정보 수정', p.nickname),
    );
  }

  Future<void> saveManagedEvent(String ownerId, WorkoutEvent event) async {
    await _authorizeOperator();
    final p = _profiles[ownerId];
    if (p == null) throw const MemberFailure('회원을 찾지 못했어요.');
    final error = event.validate();
    if (error != null) throw MemberFailure(error);
    final events = [...p.events.where((e) => e.id != event.id), event]
      ..sort((a, b) => a.start.compareTo(b.start));
    await _commit(
      {..._profiles, ownerId: p.copyWith(events: events)},
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '일정 저장',
        '${p.nickname} · ${event.title}',
      ),
    );
  }

  Future<void> deleteManagedEvent(String ownerId, String eventId) async {
    await _authorizeOperator();
    final p = _profiles[ownerId];
    if (p == null) throw const MemberFailure('회원을 찾지 못했어요.');
    await _commit(
      {
        ..._profiles,
        ownerId: p.copyWith(
          events: p.events.where((e) => e.id != eventId).toList(),
        ),
      },
      _credentials,
      sessionId,
      false,
      operations: _operations.changed('일정 삭제', p.nickname),
    );
  }

  Future<void> saveRanking(RankingEntry entry) async {
    await _authorizeOperator();
    final error = entry.validate();
    if (error != null) throw MemberFailure(error);
    await _commit(
      _profiles,
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '랭킹 저장',
        entry.name,
        rankings: [
          ..._operations.rankings.where((e) => e.id != entry.id),
          entry,
        ],
      ),
    );
  }

  Future<void> refreshRankings() async {
    final raw = await store.read();
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final operations = data['operations'];
    final updated = operations is Map
        ? OperationsData.fromJson(Map<String, dynamic>.from(operations))
        : OperationsData();
    _operations = updated;
  }

  Future<void> saveSportRanking(SportRankingEntry entry) async {
    await _authorizeOperator();
    final error = entry.validate();
    if (error != null) throw MemberFailure(error);
    final linkedIds = [
      ...entry.memberIds,
      if (entry.ownerId != null) entry.ownerId!,
    ];
    if (linkedIds.any(
      (id) =>
          id == operatorId ||
          (!_profiles.containsKey(id) && !demoProfiles.any((p) => p.id == id)),
    )) {
      throw const MemberFailure('연결할 회원을 다시 선택해주세요.');
    }
    await _commit(
      _profiles,
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '종목별 랭킹 저장',
        entry.name,
        sportRankings: [
          ..._operations.sportRankings.where((e) => e.id != entry.id),
          entry,
        ],
      ),
    );
  }

  Future<void> deleteSportRanking(String id) async {
    await _authorizeOperator();
    await _commit(
      _profiles,
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '종목별 랭킹 삭제',
        id,
        sportRankings: _operations.sportRankings
            .where((e) => e.id != id)
            .toList(),
      ),
    );
  }

  Future<void> deleteRanking(String id) async {
    await _authorizeOperator();
    await _commit(
      _profiles,
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '랭킹 삭제',
        id,
        rankings: _operations.rankings.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<void> saveRecruitment(RecruitmentPreview post) async {
    await _authorizeOperator();
    final error = post.validate();
    if (error != null) throw MemberFailure(error);
    await _commit(
      _profiles,
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '모집글 저장',
        post.title,
        posts: [..._operations.posts.where((e) => e.id != post.id), post],
      ),
    );
  }

  Future<void> deleteRecruitment(String id) async {
    await _authorizeOperator();
    await _commit(
      _profiles,
      _credentials,
      sessionId,
      false,
      operations: _operations.changed(
        '모집글 삭제',
        id,
        posts: _operations.posts.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<void> logout() async {
    final token = _operatorToken;
    await _commit(_profiles, _credentials, null, false);
    _operatorToken = null;
    if (token != null) {
      try {
        await adminGateway.logout(token);
      } catch (_) {}
    }
  }
}
