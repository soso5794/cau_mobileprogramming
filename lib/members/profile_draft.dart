import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'member_models.dart';

class ProfileDraft extends ChangeNotifier {
  ProfileDraft(this.original)
    : nickname = original.nickname,
      common = {...original.common},
      sports = [...original.sports],
      answers = original.answers.map((k, v) => MapEntry(k, {...v}));
  final MemberProfile original;
  String nickname;
  final Map<String, String> common;
  final List<String> sports;
  final Map<String, Map<String, String>> answers;
  int step = 0;
  String? error;
  List<String> get steps => [
    '기본 정보',
    '운동·모임 선호',
    ...sports.map((s) => '$s 프로필'),
    '자기소개·완료',
  ];
  bool get dirty =>
      jsonEncode(value().toJson()) != jsonEncode(original.toJson());
  MemberProfile value({String? onboarding}) => original.copyWith(
    nickname: nickname.trim(),
    common: common,
    sports: sports,
    answers: answers,
    favorites: original.favorites.intersection(sports.toSet()),
    onboarding: onboarding,
  );
  void setCommon(String k, String v) {
    common[k] = v;
    notifyListeners();
  }

  void setName(String v) {
    nickname = v;
    notifyListeners();
  }

  void toggleCommon(String k, String v) {
    final values = (common[k] ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    if (!values.add(v)) values.remove(v);
    setCommon(k, values.join(','));
  }

  void toggleSport(String sport) {
    if (sports.contains(sport)) {
      sports.remove(sport);
    } else {
      sports.add(sport);
    }
    notifyListeners();
  }

  void setAnswer(String sport, String key, String value) {
    answers.putIfAbsent(sport, () => {})[key] = value;
    notifyListeners();
  }

  String? validateStep(int index) {
    if (index == 0) {
      return MemberValidation.nickname(nickname) ??
          (MemberValidation.number(common['age'], 1, 120) != null
              ? '나이를 1~120 사이로 입력해주세요.'
              : null) ??
          (MemberValidation.number(common['height'], 80, 250) != null
              ? '키를 80~250cm 사이로 입력해주세요.'
              : null);
    }
    if (index == 1) {
      if (sports.isEmpty) return '함께할 운동을 하나 이상 선택해주세요.';
      for (final k in ['region', 'times', 'purposes']) {
        if ((common[k] ?? '').trim().isEmpty) {
          return '활동 지역, 선호 시간대, 커뮤니티 목적을 선택해주세요.';
        }
      }
    }
    if (index >= 2 && index < steps.length - 1) {
      return validateSport(sports[index - 2], answers[sports[index - 2]] ?? {});
    }
    if (index == steps.length - 1 && (common['bio'] ?? '').length > 200) {
      return '자기소개는 200자 이내로 입력해주세요.';
    }
    return null;
  }

  static String? validateSport(String sport, Map<String, String> a) {
    for (final k in ['frequency', 'duration']) {
      if ((a[k] ?? '').isEmpty) return '주간 횟수와 1회 운동 시간을 선택해주세요.';
    }
    if (sport == '농구' || sport == '축구') {
      for (final k in ['skill', 'positions', 'playerBackground']) {
        if ((a[k] ?? '').isEmpty) return '실력, 주 포지션, 선수 경험을 선택해주세요.';
      }
    }
    if (sport == '축구') {
      for (final k in ['foot', 'activityType']) {
        if ((a[k] ?? '').isEmpty) return '주발과 축구/풋살 형태를 선택해주세요.';
      }
      if (a['subPosition'] == a['positions']) return '부포지션은 주 포지션과 다르게 선택해주세요.';
    }
    if (sport == '런닝') {
      final pace = a['pace'] ?? '';
      if (pace != '모름' &&
          !RegExp(r'^(?:[1-9]|[12][0-9]):[0-5][0-9]$').hasMatch(pace)) {
        return '페이스를 분:초 형식(예: 6:30) 또는 모름으로 입력해주세요.';
      }
      if ((a['distance'] ?? '').isEmpty) return '주로 달리는 거리를 선택해주세요.';
    }
    return null;
  }

  bool next() {
    error = validateStep(step);
    if (error == null && step < steps.length - 1) step++;
    notifyListeners();
    return error == null;
  }

  void back() {
    if (step > 0) step--;
    error = null;
    notifyListeners();
  }

  bool validateAll() {
    for (var i = 0; i < steps.length; i++) {
      error = validateStep(i);
      if (error != null) {
        step = i;
        notifyListeners();
        return false;
      }
    }
    return true;
  }
}
