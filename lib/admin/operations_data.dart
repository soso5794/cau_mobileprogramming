import '../community/community_data.dart';
import '../members/member_models.dart';
import '../ranking/ranking_data.dart';
import '../features/workout_qr_session.dart';

class RankingEntry {
  const RankingEntry({
    required this.id,
    required this.name,
    required this.count,
    this.isDemo = false,
  });
  final String id, name;
  final int count;
  final bool isDemo;
  String? validate() =>
      MemberValidation.nickname(name) ??
      (count < 0 || count > 9999 ? '운동 횟수는 0~9999로 입력해주세요.' : null);
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'count': count,
    'isDemo': isDemo,
  };
  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
    id: j['id'] as String,
    name: j['name'] as String,
    count: j['count'] as int,
    isDemo: j['isDemo'] as bool? ?? false,
  );
}

class OperationLog {
  const OperationLog({
    required this.action,
    required this.target,
    required this.at,
  });
  final String action, target;
  final DateTime at;
  Map<String, String> toJson() => {
    'action': action,
    'target': target,
    'at': at.toIso8601String(),
  };
  factory OperationLog.fromJson(Map<String, dynamic> j) => OperationLog(
    action: j['action'] as String,
    target: j['target'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}

class OperationsData {
  OperationsData({
    List<RankingEntry>? rankings,
    List<SportRankingEntry>? sportRankings,
    List<RecruitmentPreview>? posts,
    List<OperationLog> logs = const [],
    List<WorkoutQrSession> workoutSessions = const [],
    List<String> processedMatchIds = const [],
  }) : rankings = List.unmodifiable(
         rankings ??
             const [
               RankingEntry(id: 'seed-1', name: '민트러너', count: 5, isDemo: true),
               RankingEntry(id: 'seed-2', name: '코트러너', count: 4, isDemo: true),
               RankingEntry(id: 'seed-3', name: '농구곰', count: 3, isDemo: true),
               RankingEntry(
                 id: 'seed-4',
                 name: '오늘도운동',
                 count: 2,
                 isDemo: true,
               ),
             ],
       ),
       sportRankings = List.unmodifiable(sportRankings ?? demoSportRankings()),
       posts = List.unmodifiable(posts ?? demoRecruitments),
       logs = List.unmodifiable(logs),
       workoutSessions = List.unmodifiable(workoutSessions),
       processedMatchIds = List.unmodifiable(processedMatchIds.toSet());
  final List<RankingEntry> rankings;
  final List<SportRankingEntry> sportRankings;
  final List<RecruitmentPreview> posts;
  final List<OperationLog> logs;
  final List<WorkoutQrSession> workoutSessions;
  final List<String> processedMatchIds;
  List<RankingEntry> get sortedRankings => [...rankings]
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount == 0 ? a.id.compareTo(b.id) : byCount;
    });
  OperationsData changed(
    String action,
    String target, {
    List<RankingEntry>? rankings,
    List<SportRankingEntry>? sportRankings,
    List<RecruitmentPreview>? posts,
    List<WorkoutQrSession>? workoutSessions,
    List<String>? processedMatchIds,
  }) => OperationsData(
    rankings: rankings ?? this.rankings,
    sportRankings: sportRankings ?? this.sportRankings,
    posts: posts ?? this.posts,
    workoutSessions: workoutSessions ?? this.workoutSessions,
    processedMatchIds: processedMatchIds ?? this.processedMatchIds,
    logs: [
      OperationLog(action: action, target: target, at: DateTime.now()),
      ...logs,
    ].take(100).toList(),
  );
  Map<String, Object> toJson() => {
    'rankings': rankings.map((e) => e.toJson()).toList(),
    'sportRankings': sportRankings.map((e) => e.toJson()).toList(),
    'posts': posts.map((e) => e.toJson()).toList(),
    'logs': logs.map((e) => e.toJson()).toList(),
    'workoutSessions': workoutSessions.map((e) => e.toJson()).toList(),
    'processedMatchIds': processedMatchIds,
  };
  factory OperationsData.fromJson(Map<String, dynamic> j) => OperationsData(
    sportRankings: (j['sportRankings'] as List?)
        ?.map(
          (e) =>
              SportRankingEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    rankings: (j['rankings'] as List)
        .map((e) => RankingEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    posts: (j['posts'] as List)
        .map(
          (e) =>
              RecruitmentPreview.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    logs: (j['logs'] as List? ?? [])
        .map((e) => OperationLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    workoutSessions: (j['workoutSessions'] as List? ?? [])
        .map((e) => WorkoutQrSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    processedMatchIds: List<String>.from(j['processedMatchIds'] as List? ?? []),
  );
}
