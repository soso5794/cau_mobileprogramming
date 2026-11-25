import '../recruitment/recruitment.dart';

/// Shared preview data for home, sport communities and recruitment details.
class RecruitmentPreview {
  const RecruitmentPreview({
    required this.id,
    required this.sport,
    required this.title,
    required this.time,
    required this.place,
    required this.condition,
    required this.people,
    required this.description,
    required this.equipment,
    this.isDemo = true,
    this.authorId,
    this.recruitmentInput,
    this.extraConditions = const [],
  });
  final bool isDemo;
  final String? authorId;
  final RecruitmentInput? recruitmentInput;
  final List<String> extraConditions;
  bool get isMemberPost => authorId != null;
  String get sourceLabel => isDemo ? '예시 모집' : isMemberPost ? '회원 등록' : '운영자 등록';
  Map<String, Object> toJson() => {
    'id': id,
    'sport': sport,
    'title': title,
    'time': time,
    'place': place,
    'condition': condition,
    'people': people,
    'description': description,
    'equipment': equipment,
    'isDemo': isDemo,
    if (authorId != null) 'authorId': authorId!,
    if (recruitmentInput != null) 'recruitmentInput': recruitmentInput!.toJson(),
    if (extraConditions.isNotEmpty) 'extraConditions': extraConditions,
  };
  factory RecruitmentPreview.fromJson(Map<String, dynamic> j) =>
      RecruitmentPreview(
        id: j['id'] as String,
        sport: j['sport'] as String,
        title: j['title'] as String,
        time: j['time'] as String,
        place: j['place'] as String,
        condition: j['condition'] as String,
        people: j['people'] as String,
        description: j['description'] as String,
        equipment: j['equipment'] as String,
        isDemo: j['isDemo'] as bool? ?? true,
        authorId: j['authorId'] as String?,
        recruitmentInput: j['recruitmentInput'] is Map
            ? RecruitmentInput.fromJson(Map<String, dynamic>.from(j['recruitmentInput'] as Map))
            : null,
        extraConditions: List<String>.from(j['extraConditions'] as List? ?? []),
      );
  String? validate() {
    if (![
      id,
      sport,
      title,
      time,
      place,
      condition,
      people,
      description,
      equipment,
    ].every((s) => s.trim().isNotEmpty && s.length <= 1000)) {
      return '모든 항목을 1~1000자로 입력해주세요.';
    }
    if (title.length > 60) return '제목은 60자 이내로 입력해주세요.';
    return null;
  }

  final String id,
      sport,
      title,
      time,
      place,
      condition,
      people,
      description,
      equipment;
}

const demoRecruitments = [
  RecruitmentPreview(
    id: 'basketball-3v3',
    sport: '농구',
    title: '가볍게 3대3 한 게임',
    time: '오늘 18:00',
    place: '학교 앞 코트',
    condition: '초보 환영 · 가드 1명',
    people: '5/6명',
    description: '승패보다 함께 즐기는 3대3 경기예요. 패스하며 호흡을 맞출 가드 한 분을 기다려요.',
    equipment: '농구화 · 물 · 개인 수건',
  ),
  RecruitmentPreview(
    id: 'running-5k',
    sport: '런닝',
    title: '저녁 공원 5km 같이 달려요',
    time: '오늘 19:30',
    place: '중앙공원',
    condition: '7분/km · 대화하며',
    people: '3/5명',
    description: '가볍게 준비운동 후 5km를 함께 달려요. 대화할 수 있는 속도로 진행해요.',
    equipment: '러닝화 · 물 · 야간 반사 용품',
  ),
  RecruitmentPreview(
    id: 'soccer-weekend',
    sport: '축구',
    title: '주말 풋살, 함께 뛸 메이트',
    time: '토요일 10:00',
    place: '동네 풋살장',
    condition: '초급 · 미드필더',
    people: '8/10명',
    description: '주말 오전 가볍게 패스하고 풋살할 메이트를 구해요. 기본 규칙을 알면 함께할 수 있어요.',
    equipment: '풋살화 · 정강이 보호대 · 물',
  ),
  RecruitmentPreview(
    id: 'basketball-shooting',
    sport: '농구',
    title: '주말 슈팅 연습 메이트',
    time: '토요일 14:00',
    place: '동네 코트',
    condition: '연습 위주',
    people: '2/4명',
    description: '서로 리바운드를 도와주며 자유투와 점프슛을 연습해요.',
    equipment: '농구공 · 농구화 · 물',
  ),
];

const demoRankingRows = [
  ('민트러너', '이번 주 5회', '1'),
  ('코트러너', '이번 주 4회', '2'),
  ('농구곰', '이번 주 3회', '3'),
  ('오늘도운동', '이번 주 2회', '4'),
];

List<RecruitmentPreview> recommendedRecruitments(
  List<String> sports,
  Set<String> favorites, {
  List<RecruitmentPreview> source = demoRecruitments,
}) {
  final posts = source.where((p) => sports.contains(p.sport)).toList();
  // Stable ordering within each group; no skill/distance claims without data.
  return [
    ...posts.where((p) => favorites.contains(p.sport)),
    ...posts.where((p) => !favorites.contains(p.sport)),
  ].take(3).toList();
}
