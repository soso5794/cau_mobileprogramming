import 'package:flutter/foundation.dart';
import '../calendar/workout_event.dart';

const memberSports = ['농구', '런닝', '축구'];
const notificationLabels = <String, String>{
  'nearby': '내 근처 모집글',
  'team': '팀·크루 소식',
  'schedule': '다가오는 일정',
  'application': '가입신청 결과',
  'changes': '일정·장소 변경',
};

@immutable
class MemberProfile {
  MemberProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.isDemo = false,
    this.onboarding = 'pending',
    Map<String, String> common = const {},
    List<String> sports = const [],
    Map<String, Map<String, String>> answers = const {},
    Set<String> favorites = const {},
    Map<String, bool> notifications = const {},
    this.reminder = 60,
    this.quietEnabled = false,
    this.quietStart = 1320,
    this.quietEnd = 480,
    List<WorkoutEvent> events = const [],
    Set<String> cancelledApplications = const {},
  }) : events = List.unmodifiable(events),
       common = Map.unmodifiable(common),
       sports = List.unmodifiable(sports),
       answers = Map.unmodifiable(
         answers.map(
           (k, v) => MapEntry(k, Map<String, String>.unmodifiable(v)),
         ),
       ),
       favorites = Set.unmodifiable(favorites),
       notifications = Map.unmodifiable({
         for (final k in notificationLabels.keys) k: true,
         'enabled': true,
         ...notifications,
       }),
       cancelledApplications = Set.unmodifiable(cancelledApplications);
  final List<WorkoutEvent> events;
  final String id, email, nickname, onboarding;
  final bool isDemo, quietEnabled;
  final Map<String, String> common;
  final List<String> sports;
  final Map<String, Map<String, String>> answers;
  final Set<String> favorites, cancelledApplications;
  final Map<String, bool> notifications;
  final int reminder, quietStart, quietEnd;
  MemberProfile copyWith({
    String? nickname,
    String? onboarding,
    Map<String, String>? common,
    List<String>? sports,
    Map<String, Map<String, String>>? answers,
    Set<String>? favorites,
    Map<String, bool>? notifications,
    int? reminder,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
    List<WorkoutEvent>? events,
    Set<String>? cancelledApplications,
  }) => MemberProfile(
    events: events ?? this.events,
    id: id,
    email: email,
    nickname: nickname ?? this.nickname,
    isDemo: isDemo,
    onboarding: onboarding ?? this.onboarding,
    common: common ?? this.common,
    sports: sports ?? this.sports,
    answers: answers ?? this.answers,
    favorites: favorites ?? this.favorites,
    notifications: notifications ?? this.notifications,
    reminder: reminder ?? this.reminder,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    cancelledApplications: cancelledApplications ?? this.cancelledApplications,
  );
  Map<String, Object?> toJson() => {
    'events': events.map((e) => e.toJson()).toList(),
    'id': id,
    'email': email,
    'nickname': nickname,
    'isDemo': isDemo,
    'onboarding': onboarding,
    'common': common,
    'sports': sports,
    'answers': answers,
    'favorites': favorites.toList(),
    'notifications': notifications,
    'reminder': reminder,
    'quietEnabled': quietEnabled,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'cancelledApplications': cancelledApplications.toList(),
  };
  factory MemberProfile.fromJson(Map<String, dynamic> j) => MemberProfile(
    events: (j['events'] as List? ?? [])
        .map((v) => WorkoutEvent.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    id: j['id'] as String,
    email: j['email'] as String,
    nickname: j['nickname'] as String,
    isDemo: j['isDemo'] as bool? ?? false,
    onboarding: j['onboarding'] as String? ?? 'pending',
    common: Map<String, String>.from(j['common'] as Map? ?? {}),
    sports: List<String>.from(j['sports'] as List? ?? []),
    answers: (j['answers'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
    ),
    favorites: Set<String>.from(j['favorites'] as List? ?? []),
    notifications: Map<String, bool>.from(j['notifications'] as Map? ?? {}),
    reminder: j['reminder'] as int? ?? 60,
    quietEnabled: j['quietEnabled'] as bool? ?? false,
    quietStart: j['quietStart'] as int? ?? 1320,
    quietEnd: j['quietEnd'] as int? ?? 480,
    cancelledApplications: Set<String>.from(
      j['cancelledApplications'] as List? ?? [],
    ),
  );
}

class MemberFailure implements Exception {
  const MemberFailure(this.message, {this.field});
  final String message;
  final String? field;
}

abstract final class MemberValidation {
  static String normalizeEmail(String s) => s.trim().toLowerCase();
  static String? email(String? v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
      ? null
      : '올바른 이메일 주소를 입력해주세요.';
  static String? nickname(String? v) =>
      (v?.trim().length ?? 0) < 2 || (v?.trim().length ?? 0) > 16
      ? '닉네임은 2~16자로 입력해주세요.'
      : null;
  static String? password(String? v) =>
      (v?.length ?? 0) < 8 ||
          !RegExp(r'[A-Za-z]').hasMatch(v ?? '') ||
          !RegExp(r'[0-9]').hasMatch(v ?? '')
      ? '영문과 숫자를 포함해 8자 이상 입력해주세요.'
      : null;
  static String? number(String? v, int min, int max, {bool required = false}) {
    if ((v ?? '').trim().isEmpty) return required ? '값을 입력해주세요.' : null;
    final n = int.tryParse(v!.trim());
    return n == null || n < min || n > max ? '$min~$max 사이의 숫자를 입력해주세요.' : null;
  }
}
