import 'dart:convert';
import '../admin/admin_gateway.dart';
import '../admin/operations_data.dart';
import '../community/community_data.dart';
import '../recruitment/recruitment.dart';
import 'dart:math';
import '../calendar/workout_event.dart';
import '../ranking/ranking_data.dart';
import '../features/workout_qr_session.dart';
import '../features/workout_tier.dart';

import 'member_models.dart';
import 'member_store.dart';
import 'password_reset_service.dart';

MemberProfile _demoMate({
  required String id,
  required String nickname,
  required List<String> sports,
  required String region,
  required String times,
  required String purposes,
  required Map<String, Map<String, String>> answers,
  required int tierXp,
  String? bio,
  String? place,
}) => MemberProfile(
  id: id,
  email: '$id@demo.invalid',
  nickname: nickname,
  isDemo: true,
  onboarding: 'complete',
  sports: sports,
  common: {
    'region': region,
    'times': times,
    'purposes': purposes,
    if (bio != null) 'bio': bio,
    if (place != null) 'place': place,
  },
  answers: answers,
  tierExperiencePoints: tierXp,
);

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

  /// Local-device profiles plus built-in demo profiles for the matching prototype.
  /// Only public sport-preference fields are rendered by the matching screen.
  List<MemberProfile> get matchingProfiles {
    final all = <String, MemberProfile>{
      for (final p in MemberRepository.demoProfiles) p.id: p,
      for (final p in _profiles.values) p.id: p,
    };
    return List.unmodifiable(
      all.values.where((p) => p.onboarding == 'complete' && p.id != operatorId),
    );
  }
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
      tierExperiencePoints: 340,
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
      tierExperiencePoints: 95,
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
      tierExperiencePoints: 180,
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
    _demoMate(
      id: 'demo-basketball-gwanak', nickname: '코트의 지휘자', sports: ['농구'],
      region: '서울 관악구', times: '주말 오후', purposes: '경기·승부,연습·성장', tierXp: 720,
      place: '낙성대 농구장', bio: '패스 중심으로 팀플레이하는 걸 좋아해요.',
      answers: {'농구': {'frequency': '주 3회', 'duration': '90분', 'skill': '중급', 'positions': '포인트가드', 'activityType': '5대5', 'playerBackground': '학교 운동부'}},
    ),
    _demoMate(
      id: 'demo-basketball-incheon', nickname: '리바운드왕', sports: ['농구'],
      region: '인천 연수구', times: '평일 저녁', purposes: '친목·취미,건강·체력', tierXp: 145,
      place: '송도 센트럴파크 코트', bio: '초보도 편하게 같이 뛸 수 있는 분위기를 원해요.',
      answers: {'농구': {'frequency': '주 2회', 'duration': '60분', 'skill': '초급', 'positions': '센터', 'activityType': '3대3', 'playerBackground': '없음'}},
    ),
    _demoMate(
      id: 'demo-basketball-suwon', nickname: '스텝백', sports: ['농구'],
      region: '경기 수원시 영통구', times: '평일 저녁,주말 오전', purposes: '경기·승부', tierXp: 1520,
      place: '광교 호수공원 코트', bio: '빠른 템포의 5대5 경기를 선호해요.',
      answers: {'농구': {'frequency': '주 4회 이상', 'duration': '120분', 'skill': '상급', 'positions': '슈팅가드', 'activityType': '5대5', 'playerBackground': '학교 운동부'}},
    ),
    _demoMate(
      id: 'demo-basketball-yongsan', nickname: '미드레인지', sports: ['농구'],
      region: '서울 용산구', times: '주말 오전', purposes: '건강·체력,친목·취미', tierXp: 460,
      place: '용산 가족공원', bio: '가볍게 운동하고 커피도 한잔해요.',
      answers: {'농구': {'frequency': '주 1회', 'duration': '60분', 'skill': '입문', 'positions': '파워포워드', 'activityType': '3대3', 'playerBackground': '없음'}},
    ),
    _demoMate(
      id: 'demo-basketball-seongnam', nickname: '코트 러너', sports: ['농구'],
      region: '경기 성남시 분당구', times: '평일 저녁', purposes: '연습·성장', tierXp: 260,
      place: '탄천 종합운동장 코트', bio: '기본기와 슈팅 연습을 함께하고 싶어요.',
      answers: {'농구': {'frequency': '주 2회', 'duration': '90분', 'skill': '중급', 'positions': '스몰포워드', 'activityType': '슈팅 연습', 'playerBackground': '없음'}},
    ),
    _demoMate(
      id: 'demo-running-seoul', nickname: '한강 페이스메이커', sports: ['런닝'],
      region: '서울 마포구', times: '평일 새벽,주말 오전', purposes: '기록·성장,건강·체력', tierXp: 1080,
      place: '여의도 한강공원', bio: '10km 페이스를 안정적으로 유지하는 게 목표예요.',
      answers: {'런닝': {'frequency': '주 4회 이상', 'duration': '60분', 'pace': '5:10', 'distance': '10km', 'watch': 'Garmin'}},
    ),
    _demoMate(
      id: 'demo-running-easy', nickname: '천천히 오래', sports: ['런닝'],
      region: '서울 동작구', times: '주말 오전', purposes: '친목·취미,건강·체력', tierXp: 65,
      place: '보라매공원', bio: '대화 가능한 편안한 페이스로 달리고 싶어요.',
      answers: {'런닝': {'frequency': '주 2회', 'duration': '40분', 'pace': '7:20', 'distance': '5km', 'watch': 'Galaxy Watch'}},
    ),
    _demoMate(
      id: 'demo-running-fast', nickname: '페이스 체이서', sports: ['런닝'],
      region: '서울 송파구', times: '평일 저녁', purposes: '기록·성장,경기·승부', tierXp: 2650,
      place: '올림픽공원', bio: '인터벌과 템포런을 함께할 메이트를 찾아요.',
      answers: {'런닝': {'frequency': '주 4회 이상', 'duration': '60분', 'pace': '4:35', 'distance': '10km', 'watch': 'Apple Watch'}},
    ),
    _demoMate(
      id: 'demo-running-incheon', nickname: '바다 러너', sports: ['런닝'],
      region: '인천 연수구', times: '주말 오후', purposes: '건강·체력', tierXp: 510,
      place: '송도 센트럴파크', bio: '5km 완주부터 차근차근 도전 중입니다.',
      answers: {'런닝': {'frequency': '주 1회', 'duration': '30분', 'pace': '8:00', 'distance': '3km 이하', 'watch': '없음'}},
    ),
    _demoMate(
      id: 'demo-running-suwon', nickname: '롱런 메이커', sports: ['런닝'],
      region: '경기 수원시 영통구', times: '주말 오전,평일 저녁', purposes: '기록·성장', tierXp: 1950,
      place: '광교 호수공원', bio: '하프 마라톤 준비 중이에요.',
      answers: {'런닝': {'frequency': '주 3회', 'duration': '120분', 'pace': '5:45', 'distance': '하프', 'watch': 'Garmin'}},
    ),
    _demoMate(
      id: 'demo-soccer-goalkeeper', nickname: '최후방 수호자', sports: ['축구'],
      region: '서울 관악구', times: '주말 오후', purposes: '경기·승부,친목·취미', tierXp: 880,
      place: '관악 풋살파크', bio: '골키퍼입니다. 팀 밸런스를 중요하게 생각해요.',
      answers: {'축구': {'frequency': '주 2회', 'duration': '120분', 'skill': '중급', 'positions': '골키퍼', 'subPosition': '수비수', 'foot': '오른발', 'activityType': '풋살', 'playerBackground': '학교 운동부'}},
    ),
    _demoMate(
      id: 'demo-soccer-forward', nickname: '침투하는 공격수', sports: ['축구'],
      region: '서울 동작구', times: '평일 저녁', purposes: '경기·승부,기록·성장', tierXp: 1730,
      place: '보라매 풋살장', bio: '빠른 패스와 침투 플레이를 선호해요.',
      answers: {'축구': {'frequency': '주 3회', 'duration': '90분', 'skill': '상급', 'positions': '공격수', 'subPosition': '미드필더', 'foot': '양발', 'activityType': '풋살', 'playerBackground': '학교 운동부'}},
    ),
    _demoMate(
      id: 'demo-soccer-defender', nickname: '빌드업 수비수', sports: ['축구'],
      region: '경기 고양시 일산동구', times: '주말 오전', purposes: '연습·성장,건강·체력', tierXp: 315,
      place: '일산 종합운동장', bio: '수비 라인과 빌드업을 함께 맞춰보고 싶어요.',
      answers: {'축구': {'frequency': '주 2회', 'duration': '120분', 'skill': '초급', 'positions': '수비수', 'subPosition': '미드필더', 'foot': '왼발', 'activityType': '축구', 'playerBackground': '없음'}},
    ),
    _demoMate(
      id: 'demo-soccer-midfield', nickname: '중원의 엔진', sports: ['축구'],
      region: '서울 마포구', times: '평일 저녁,주말 오후', purposes: '연습·성장,친목·취미', tierXp: 1240,
      place: '월드컵공원 풋살장', bio: '많이 뛰고 연결하는 미드필더예요.',
      answers: {'축구': {'frequency': '주 4회 이상', 'duration': '120분', 'skill': '중급', 'positions': '미드필더', 'subPosition': '수비수', 'foot': '오른발', 'activityType': '둘 다', 'playerBackground': '없음'}},
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
      {..._profiles, p.id: p.copyWith(
        events: original.events,
        verifiedSessionIds: original.verifiedSessionIds,
        tierExperiencePoints: original.tierExperiencePoints,
      )},
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

  Future<void> createWorkoutQrSession(WorkoutQrSession session) async {
    final owner = current;
    if (owner == null || isOperator || owner.id != session.hostId) {
      throw const MemberFailure('회원 계정으로 로그인한 뒤 QR을 발급해주세요.');
    }
    final issue = session.validateForIssue();
    if (issue != null) throw MemberFailure(issue);
    if (owner.verifiedSessionIds.contains(session.id) ||
        _operations.workoutSessions.any((e) => e.id == session.id)) {
      throw const MemberFailure('이미 사용 중인 운동 인증 ID예요. 다시 발급해주세요.');
    }

    final event = _attendanceEvent(session);
    final earnedXp = WorkoutTier.xpForSession(session);
    final updatedOwner = owner.copyWith(
      events: [...owner.events.where((e) => e.id != event.id), event],
      verifiedSessionIds: {...owner.verifiedSessionIds, session.id},
      tierExperiencePoints: owner.tierExperiencePoints + earnedXp,
    );
    final updatedSessions = [
      session.withAttendees([owner.id]),
      ..._operations.workoutSessions.where((e) => e.id != session.id),
    ];
    await _commit(
      {..._profiles, owner.id: updatedOwner},
      _credentials,
      sessionId,
      _remember,
      operations: _operations.changed(
        'QR 운동 티어 경험치 획득',
        '${owner.nickname} · ${session.sport} · +$earnedXp XP',
        workoutSessions: updatedSessions,
      ),
    );
  }

  Future<void> confirmWorkoutQrSession(WorkoutQrSession session) async {
    final participant = current;
    if (participant == null || isOperator) {
      throw const MemberFailure('회원 계정으로 로그인한 뒤 인증해주세요.');
    }
    final issue = session.validateForQr();
    if (issue != null) throw MemberFailure(issue);
    if (session.isHostedBy(participant.id)) {
      throw const MemberFailure('본인이 발급한 QR은 다른 메이트가 스캔해야 해요.');
    }
    if (participant.verifiedSessionIds.contains(session.id)) {
      throw const MemberFailure('이미 인증한 운동이에요. 중복 기록은 저장하지 않았어요.');
    }

    final existing = _operations.workoutSessions
        .where((e) => e.id == session.id)
        .firstOrNull;
    final base = existing ?? session;
    if (base.attendeeIds.contains(participant.id)) {
      throw const MemberFailure('이미 출석 처리된 계정이에요.');
    }

    final event = _attendanceEvent(session);
    final earnedXp = WorkoutTier.xpForSession(session);
    final updatedParticipant = participant.copyWith(
      events: [...participant.events.where((e) => e.id != event.id), event],
      verifiedSessionIds: {...participant.verifiedSessionIds, session.id},
      tierExperiencePoints: participant.tierExperiencePoints + earnedXp,
    );
    final attendees = [...base.attendeeIds, participant.id];
    final updatedSessions = [
      base.withAttendees(attendees),
      ..._operations.workoutSessions.where((e) => e.id != session.id),
    ];

    await _commit(
      {..._profiles, participant.id: updatedParticipant},
      _credentials,
      sessionId,
      _remember,
      operations: _operations.changed(
        'QR 운동 티어 경험치 획득',
        '${participant.nickname} · ${session.sport} · +$earnedXp XP',
        workoutSessions: updatedSessions,
      ),
    );
  }


  WorkoutEvent _attendanceEvent(WorkoutQrSession session) => WorkoutEvent(
    id: 'qr-event-${session.id}',
    title: '${session.sport} 운동 인증',
    sport: session.sport,
    start: session.matchAt,
    minutes: session.isRunning
        ? ((session.seconds ?? 3600) ~/ 60).clamp(10, 720).toInt()
        : 90,
    place: session.place,
    notes: session.isRunning
        ? 'QR 출석 인증 · ${session.resultLabel}'
        : 'QR 출석 인증 · ${session.teamName} ${session.resultLabel} ${session.opponentName}',
    completed: true,
  );

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

  /// A member may create a new post, never overwrite an existing post.
  Future<void> publishRecruitment(RecruitmentInput input, RecruitmentDraft draft,
      {required String ownerId}) async {
    final owner = current;
    if (owner == null || owner.id != ownerId || isOperator || owner.id == operatorId) {
      throw const MemberFailure('회원 계정으로 다시 로그인해주세요.');
    }
    final issue = input.validate();
    if (issue != null) throw MemberFailure(issue);
    if (draft.conditions.length > 12 || draft.conditions.any((c) => c.trim().isEmpty || c.length > 120)) {
      throw const MemberFailure('추가 조건을 확인해주세요.');
    }
    final random = Random.secure();
    final suffix = List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final post = RecruitmentPreview(
      id: 'member-$suffix', sport: input.sport, title: draft.title.trim(),
      time: input.schedule, place: input.place.trim(),
      condition: [input.intensity, ...input.fields.entries.map((e) => '${e.key}: ${e.value}')].join(' · '),
      people: '모집 ${input.minPeople}~${input.maxPeople}명',
      description: draft.body.trim(), equipment: '추가 조건 및 본문 참고',
      isDemo: false, authorId: owner.id, recruitmentInput: input,
      extraConditions: List.unmodifiable(draft.conditions),
    );
    final error = post.validate();
    if (error != null) throw MemberFailure(error);
    if (_operations.posts.any((p) => p.id == post.id)) {
      throw const MemberFailure('다시 등록해주세요.');
    }
    await _commit(_profiles, _credentials, sessionId, _remember,
      operations: _operations.changed('회원 모집글 등록', post.title,
        posts: [post, ..._operations.posts]));
  }

  Future<void> saveRecruitment(RecruitmentPreview post) async {
    await _authorizeOperator();
    if (post.isMemberPost || _operations.posts.any((p) => p.id == post.id && p.isMemberPost)) {
      throw const MemberFailure('회원 모집글은 운영자 화면에서 수정할 수 없어요.');
    }
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
