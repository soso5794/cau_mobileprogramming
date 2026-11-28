import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../ranking/ranking_data.dart';

/// QR code data for a completed, user-confirmed sports session.
///
/// This is a local prototype format. The payload is time-limited and validated,
/// but without a trusted backend signature it must not be treated as tamper-proof.
class WorkoutQrSession {
  const WorkoutQrSession({
    required this.id,
    required this.sport,
    required this.teamName,
    required this.opponentName,
    required this.place,
    required this.hostId,
    required this.matchAt,
    required this.issuedAt,
    this.teamScore,
    this.opponentScore,
    this.distance,
    this.seconds,
    this.attendeeIds = const [],
  });

  static const String qrPrefix = 'EXERCISE_ASSIST_V1:';

  final String id;
  final String sport;
  final String teamName;
  final String opponentName;
  final String place;
  final String hostId;
  final DateTime matchAt;
  final DateTime issuedAt;
  final int? teamScore;
  final int? opponentScore;
  final RunningDistance? distance;
  final int? seconds;
  final List<String> attendeeIds;

  bool get isRunning => sport == '런닝';

  /// QR payloads use a one-way account fingerprint instead of exposing email IDs.
  bool isHostedBy(String memberId) => hostId == accountFingerprint(memberId);

  static String accountFingerprint(String memberId) =>
      sha256.convert(utf8.encode(memberId)).toString();

  String get resultLabel => isRunning
      ? '${distance?.label ?? '러닝'} · ${formatRunningTime(seconds ?? 0)}'
      : '${teamScore ?? 0} : ${opponentScore ?? 0}';

  String toQrPayload() {
    final payload = <String, Object?>{
      'v': 1,
      'id': id,
      'sport': sport,
      'team': teamName,
      'opponent': opponentName,
      'place': place,
      'host': accountFingerprint(hostId),
      'matchAt': matchAt.toIso8601String(),
      'issuedAt': issuedAt.toIso8601String(),
      'teamScore': teamScore,
      'opponentScore': opponentScore,
      'distance': distance?.name,
      'seconds': seconds,
    };
    return '$qrPrefix${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sport': sport,
    'teamName': teamName,
    'opponentName': opponentName,
    'place': place,
    'hostId': hostId,
    'matchAt': matchAt.toIso8601String(),
    'issuedAt': issuedAt.toIso8601String(),
    'teamScore': teamScore,
    'opponentScore': opponentScore,
    'distance': distance?.name,
    'seconds': seconds,
    'attendeeIds': attendeeIds,
  };

  factory WorkoutQrSession.fromJson(Map<String, dynamic> json) =>
      WorkoutQrSession(
        id: json['id'] as String,
        sport: json['sport'] as String,
        teamName: json['teamName'] as String,
        opponentName: json['opponentName'] as String,
        place: json['place'] as String,
        hostId: json['hostId'] as String,
        matchAt: DateTime.parse(json['matchAt'] as String),
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        teamScore: json['teamScore'] as int?,
        opponentScore: json['opponentScore'] as int?,
        distance: json['distance'] == null
            ? null
            : RunningDistance.values.byName(json['distance'] as String),
        seconds: json['seconds'] as int?,
        attendeeIds: List<String>.from(json['attendeeIds'] as List? ?? []),
      );

  factory WorkoutQrSession.fromQrPayload(String raw, {DateTime? now}) {
    if (!raw.startsWith(qrPrefix)) {
      throw const FormatException('운동 Assist에서 발급한 QR 코드가 아니에요.');
    }
    try {
      final encoded = raw.substring(qrPrefix.length);
      final normalized = base64Url.normalize(encoded);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is! Map) {
        throw const FormatException('QR 데이터 형식이 올바르지 않아요.');
      }
      final json = Map<String, dynamic>.from(decoded);
      if (json['v'] != 1) {
        throw const FormatException('지원하지 않는 QR 코드 버전이에요.');
      }
      final session = WorkoutQrSession(
        id: json['id'] as String,
        sport: json['sport'] as String,
        teamName: json['team'] as String,
        opponentName: json['opponent'] as String,
        place: json['place'] as String,
        hostId: json['host'] as String,
        matchAt: DateTime.parse(json['matchAt'] as String),
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        teamScore: json['teamScore'] as int?,
        opponentScore: json['opponentScore'] as int?,
        distance: json['distance'] == null
            ? null
            : RunningDistance.values.byName(json['distance'] as String),
        seconds: json['seconds'] as int?,
        attendeeIds: [json['host'] as String],
      );
      final issue = session.validateForQr(now: now);
      if (issue != null) throw FormatException(issue);
      return session;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('QR 코드의 운동 정보가 손상되었어요.');
    }
  }

  WorkoutQrSession withAttendees(List<String> ids) => WorkoutQrSession(
    id: id,
    sport: sport,
    teamName: teamName,
    opponentName: opponentName,
    place: place,
    hostId: hostId,
    matchAt: matchAt,
    issuedAt: issuedAt,
    teamScore: teamScore,
    opponentScore: opponentScore,
    distance: distance,
    seconds: seconds,
    attendeeIds: List.unmodifiable(ids.toSet()),
  );

  String? validateForIssue({DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (id.trim().isEmpty || id.length > 80 || hostId.trim().isEmpty || hostId.length > 254) {
      return '운동 인증 ID를 확인해주세요.';
    }
    if (!const ['농구', '축구', '런닝'].contains(sport)) {
      return 'QR 경기 인증은 농구·축구·런닝만 지원해요.';
    }
    if (teamName.trim().length < 2 || teamName.length > 30 ||
        opponentName.trim().length < 2 || opponentName.length > 30) {
      return '팀·상대 이름은 2~30자로 입력해주세요.';
    }
    if (teamName.trim().toLowerCase() == opponentName.trim().toLowerCase()) {
      return '우리 팀과 상대 팀 이름은 서로 달라야 해요.';
    }
    if (place.trim().isEmpty || place.length > 100) {
      return '운동 장소는 1~100자로 입력해주세요.';
    }
    if (matchAt.year < 2000 || matchAt.isAfter(clock.add(const Duration(minutes: 5))) ||
        matchAt.isBefore(clock.subtract(const Duration(days: 7)))) {
      return '경기 시간은 최근 7일 이내로 입력해주세요.';
    }
    if (issuedAt.isAfter(clock.add(const Duration(minutes: 5)))) {
      return '발급 시간이 올바르지 않아요.';
    }
    if (sport == '런닝') {
      if (distance == null || seconds == null || seconds! < 1 || seconds! > 86399) {
        return '러닝 거리와 완주 시간을 확인해주세요.';
      }
    } else {
      if (teamScore == null || opponentScore == null ||
          teamScore! < 0 || opponentScore! < 0 ||
          teamScore! > 999 || opponentScore! > 999) {
        return '경기 점수는 0~999 사이로 입력해주세요.';
      }
      if (sport == '농구' && teamScore == opponentScore) {
        return '농구 경기는 무승부 없이 승패를 입력해주세요.';
      }
    }
    return null;
  }

  String? validateForQr({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final issue = validateForIssue(now: clock);
    if (issue != null) return issue;
    if (issuedAt.isBefore(clock.subtract(const Duration(hours: 48)))) {
      return 'QR 코드가 만료되었어요. 운동 주최자에게 새 코드를 요청해주세요.';
    }
    if (issuedAt.isAfter(clock.add(const Duration(minutes: 5)))) {
      return '아직 사용할 수 없는 QR 코드예요.';
    }
    return null;
  }
}
