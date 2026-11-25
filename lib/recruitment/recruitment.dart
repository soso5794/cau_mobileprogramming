import 'recruitment_location.dart';

/// The user's structured inputs remain authoritative, even after editing AI text.
class RecruitmentInput {
  const RecruitmentInput({required this.sport, required this.start,
    required this.end, required this.place, required this.minPeople,
    required this.maxPeople, required this.intensity, required this.fields,
    required this.details, required this.allowMerge, this.location});
  final String sport, place, intensity, details;
  final DateTime start, end;
  final int minPeople, maxPeople;
  final Map<String, String> fields;
  final bool allowMerge;
  final RecruitmentLocation? location;

  Map<String, dynamic> toJson() => {
    'sport': sport, 'start': start.toIso8601String(), 'end': end.toIso8601String(),
    'place': place, 'minPeople': minPeople, 'maxPeople': maxPeople,
    'intensity': intensity, 'fields': fields, 'details': details,
    'allowMerge': allowMerge,
    if (location != null) 'location': location!.toJson(),
  };
  factory RecruitmentInput.fromJson(Map<String, dynamic> j) => RecruitmentInput(
    sport: j['sport'] as String, start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String), place: j['place'] as String,
    minPeople: j['minPeople'] as int, maxPeople: j['maxPeople'] as int,
    intensity: j['intensity'] as String, fields: Map<String,String>.from(j['fields'] as Map),
    details: j['details'] as String, allowMerge: j['allowMerge'] as bool,
    location: j['location'] is Map ? RecruitmentLocation.fromJson(Map<String,dynamic>.from(j['location'] as Map)) : null,
  );
  String? validate({DateTime? now}) {
    if (!(const ['농구','런닝','축구','요트','등산','카약','자전거']).contains(sport)) return '지원하지 않는 종목이에요.';
    if (!(const ['가볍게','보통','강하게']).contains(intensity)) return '운동 강도를 확인해주세요.';
    if (fields.length > 8 || fields.entries.any((e) => e.key.trim().isEmpty || e.key.length > 40 || e.value.trim().isEmpty || e.value.length > 120)) return '종목별 조건을 확인해주세요.';
    if (place.trim().isEmpty || place.length > 120) return '장소를 1~120자로 입력해주세요.';
    if (location != null && (!location!.isValid || location!.name != place.trim())) return '지도 위치와 장소명을 확인해주세요.';
    if (start.year != end.year || start.month != end.month || start.day != end.day || !end.isAfter(start)) return '종료 시간은 시작 시간보다 늦어야 해요.';
    if (!start.isAfter(now ?? DateTime.now())) return '미래의 운동 시간을 선택해주세요.';
    if (minPeople < 1 || maxPeople < minPeople || maxPeople > 100) return '모집 인원은 1~100명이며 최소 인원은 최대 인원 이하여야 해요.';
    if (details.length > 1000) return '추가사항은 1000자 이내로 작성해주세요.';
    return null;
  }
  String get schedule => '${start.year}.${start.month}.${start.day} ${clock(start)}~${clock(end)}';
  static String clock(DateTime d) => '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

class RecruitmentDraft {
  const RecruitmentDraft(this.title, this.body, {this.conditions = const []});
  final String title, body;
  final List<String> conditions;
  factory RecruitmentDraft.fromJson(Map<String,dynamic> j) => RecruitmentDraft(
    j['title'] as String, j['body'] as String,
    conditions: List<String>.from(j['conditions'] as List? ?? []),
  );
  Map<String,dynamic> toJson() => {'title':title,'body':body,'conditions':conditions};
  factory RecruitmentDraft.manual(RecruitmentInput input) => RecruitmentDraft(
    '${input.sport} 함께하실 분 모집',
    input.details.isEmpty ? '${input.sport} 함께하실 분을 모집합니다.' : input.details,
  );
}
