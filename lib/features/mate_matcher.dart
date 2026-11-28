import '../members/member_models.dart';
import 'workout_tier.dart';

class MateMatchResult {
  const MateMatchResult({required this.score, required this.reasons});
  final int score;
  final List<String> reasons;
}

/// Transparent weighted matching for profiles that selected the same sport.
/// It favors practical compatibility over matching only by broad interests.
class MateMatcher {
  static MateMatchResult evaluate({
    required MemberProfile me,
    required MemberProfile candidate,
    required String sport,
  }) {
    if (me.id == candidate.id || !me.sports.contains(sport) || !candidate.sports.contains(sport)) {
      return const MateMatchResult(score: 0, reasons: ['같은 종목의 다른 회원만 추천해요.']);
    }

    final mine = me.answers[sport] ?? const <String, String>{};
    final theirs = candidate.answers[sport] ?? const <String, String>{};
    var score = 0;
    final reasons = <String>[];

    final skill = _skillScore(sport, mine, theirs);
    score += skill;
    if (skill >= 20) {
      reasons.add(sport == '런닝' ? '러닝 페이스가 잘 맞아요' : '운동 실력 수준이 비슷해요');
    } else if (skill <= 11) {
      reasons.add('실력 차이를 고려해 도전적인 상대예요');
    }

    final region = _regionScore(me.common['region'] ?? '', candidate.common['region'] ?? '');
    score += region;
    if (region >= 17) {
      reasons.add('활동 지역이 가까워요');
    } else if (region <= 5) {
      reasons.add('지역은 다르지만 다른 조건을 함께 고려했어요');
    }

    final time = _timeScore(me.common['times'] ?? '', candidate.common['times'] ?? '');
    score += time;
    if (time >= 15) reasons.add('선호 운동 시간대가 겹쳐요');

    final purpose = _purposeScore(me.common['purposes'] ?? '', candidate.common['purposes'] ?? '');
    score += purpose;
    if (purpose >= 8) reasons.add('운동 목적과 분위기가 잘 맞아요');

    final position = _positionScore(sport, mine['positions'] ?? '', theirs['positions'] ?? '');
    score += position;
    if (position >= 8) reasons.add('포지션 조합이 좋아요');

    final frequency = _frequencyScore(mine['frequency'], theirs['frequency']);
    score += frequency;
    if (frequency >= 4) reasons.add('주간 운동 횟수가 비슷해요');

    final format = _formatScore(sport, mine, theirs);
    score += format;
    if (format >= 4) {
      reasons.add(sport == '런닝' ? '목표 러닝 거리가 비슷해요' : '선호 경기 방식이 같아요');
    }

    final activity = _tierActivityScore(me.tierExperiencePoints, candidate.tierExperiencePoints);
    score += activity;
    if (activity >= 4) reasons.add('운동 활동 경험이 비슷해요');

    if (reasons.isEmpty) reasons.add('프로필의 전체 조건을 종합해 추천해요');
    return MateMatchResult(score: score.clamp(0, 100).toInt(), reasons: reasons.take(4).toList());
  }

  static int _skillScore(String sport, Map<String, String> a, Map<String, String> b) {
    if (sport == '런닝') {
      final paceA = _parsePace(a['pace']);
      final paceB = _parsePace(b['pace']);
      if (paceA == null || paceB == null) return 15;
      final difference = (paceA - paceB).abs();
      if (difference <= 20) return 25;
      if (difference <= 40) return 22;
      if (difference <= 60) return 19;
      if (difference <= 90) return 15;
      if (difference <= 120) return 11;
      return 6;
    }
    const levels = ['입문', '초급', '중급', '상급'];
    final left = levels.indexOf(a['skill'] ?? '');
    final right = levels.indexOf(b['skill'] ?? '');
    if (left < 0 || right < 0) return 15;
    final gap = (left - right).abs();
    return switch (gap) { 0 => 25, 1 => 21, 2 => 14, _ => 7 };
  }

  static int _regionScore(String a, String b) {
    final left = a.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final right = b.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (left.isEmpty || right.isEmpty) return 10;
    if (a.trim() == b.trim()) return 20;
    if (left.first == right.first) {
      if (left.length > 1 && right.length > 1 && left[1] == right[1]) return 18;
      return 15;
    }
    if (_sameProvince(left.first, right.first)) return 9;
    return 3;
  }

  static bool _sameProvince(String a, String b) {
    String normalize(String value) {
      const aliases = {
        '서울특별시': '서울',
        '인천광역시': '인천',
        '부산광역시': '부산',
        '대구광역시': '대구',
        '대전광역시': '대전',
        '광주광역시': '광주',
        '울산광역시': '울산',
        '세종특별자치시': '세종',
      };
      return aliases[value] ?? value
          .replaceAll('특별자치도', '')
          .replaceAll('특별자치시', '')
          .replaceAll('특별시', '')
          .replaceAll('광역시', '')
          .replaceAll('도', '');
    }
    return normalize(a) == normalize(b);
  }

  static int _timeScore(String a, String b) {
    final left = _timeTokens(a);
    final right = _timeTokens(b);
    if (left.isEmpty || right.isEmpty) return 10;
    final overlap = left.intersection(right).length;
    if (overlap >= 2) return 20;
    if (overlap == 1) return 14;
    return 4;
  }

  static Set<String> _timeTokens(String value) {
    final tokens = <String>{};
    for (final token in ['평일', '주말', '새벽', '오전', '오후', '저녁']) {
      if (value.contains(token)) {
        if (token == '새벽' || token == '오전') {
          tokens.add('morning');
        } else if (token == '오후' || token == '저녁') {
          tokens.add('evening');
        } else {
          tokens.add(token);
        }
      }
    }
    return tokens;
  }

  static int _purposeScore(String a, String b) {
    final left = _purposeKinds(a);
    final right = _purposeKinds(b);
    if (left.isEmpty || right.isEmpty) return 5;
    if (left.intersection(right).isNotEmpty) return 10;
    return 3;
  }

  static Set<String> _purposeKinds(String value) {
    final kinds = <String>{};
    if (value.contains('경기') || value.contains('승부')) kinds.add('competition');
    if (value.contains('연습') || value.contains('성장') || value.contains('기록')) kinds.add('improvement');
    if (value.contains('친목') || value.contains('취미')) kinds.add('social');
    if (value.contains('건강') || value.contains('체력')) kinds.add('health');
    return kinds;
  }

  static int _positionScore(String sport, String a, String b) {
    if (sport == '런닝' || a.isEmpty || b.isEmpty || a == '미정' || b == '미정') return 5;
    if (a == b) return 5;
    if (sport == '농구') {
      final group = (String value) {
        if (value.contains('가드')) return 'guard';
        if (value.contains('포워드')) return 'forward';
        if (value == '센터') return 'center';
        return 'unknown';
      };
      final ga = group(a), gb = group(b);
      if (ga == 'unknown' || gb == 'unknown') return 5;
      if (ga != gb) return 10;
      return 7;
    }
    if (a == '골키퍼' || b == '골키퍼') return 10;
    if ((a == '미드필더' && b != '미드필더') || (b == '미드필더' && a != '미드필더')) return 9;
    return 7;
  }

  static int _frequencyScore(String? a, String? b) {
    final left = _frequency(a), right = _frequency(b);
    if (left == null || right == null) return 3;
    final gap = (left - right).abs();
    return gap == 0 ? 5 : gap == 1 ? 4 : gap == 2 ? 2 : 1;
  }

  static int _formatScore(String sport, Map<String, String> a, Map<String, String> b) {
    final key = sport == '런닝' ? 'distance' : 'activityType';
    final left = a[key] ?? '', right = b[key] ?? '';
    if (left.isEmpty || right.isEmpty) return 3;
    if (left == right) return 5;
    if (sport == '런닝') {
      final order = ['3km 이하', '5km', '10km', '하프', '풀'];
      final leftIndex = order.indexOf(left);
      final rightIndex = order.indexOf(right);
      if (leftIndex < 0 || rightIndex < 0) return 3;
      final gap = (leftIndex - rightIndex).abs();
      return gap == 0 ? 5 : gap == 1 ? 4 : 2;
    }
    if (left == '둘 다' || right == '둘 다') return 4;
    return 2;
  }

  static int _tierActivityScore(int aXp, int bXp) {
    final gap = (WorkoutTier.indexForXp(aXp) - WorkoutTier.indexForXp(bXp)).abs();
    return gap == 0 ? 5 : gap <= 2 ? 4 : gap <= 4 ? 2 : 1;
  }

  static int? _frequency(String? value) {
    final match = RegExp(r'\d+').firstMatch(value ?? '');
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static int? _parsePace(String? value) {
    if (value == null || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value.trim())) return null;
    final parts = value.trim().split(':').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;
    if (parts[1]! > 59) return null;
    return parts[0]! * 60 + parts[1]!;
  }
}
