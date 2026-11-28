enum RankingSport {
  basketball('농구'),
  running('러닝'),
  soccer('축구');

  const RankingSport(this.label);
  final String label;
}

enum RunningDistance {
  five('5km', '5km'),
  ten('10km', '10km'),
  half('하프', '21.0975km'),
  full('풀', '42.195km');

  const RunningDistance(this.label, this.description);
  final String label, description;
}

/// Operator-entered team totals or a single completed running record.
/// Account IDs, rather than display names, determine personal rankings.
class SportRankingEntry {
  SportRankingEntry({
    required this.id,
    required this.sport,
    required this.name,
    this.ownerId,
    List<String> memberIds = const [],
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.distance,
    this.seconds,
    this.achievedAt,
    this.isDemo = false,
  }) : memberIds = List.unmodifiable(memberIds);

  final String id, name;
  final RankingSport sport;
  final String? ownerId;
  final List<String> memberIds;
  final int wins, draws, losses, goalsFor, goalsAgainst;
  final RunningDistance? distance;
  final int? seconds;
  final DateTime? achievedAt;
  final bool isDemo;

  int get games => wins + draws + losses;
  int get points => wins * 3 + draws;
  int get goalDifference => goalsFor - goalsAgainst;
  double get winRate => games == 0 ? 0 : wins / games * 100;
  bool belongsTo(String? accountId) =>
      accountId != null &&
      (sport == RankingSport.running
          ? ownerId == accountId
          : memberIds.contains(accountId));

  String? validate({DateTime? now}) {
    if (id.trim().isEmpty || id.length > 160) return '기록 ID를 확인해주세요.';
    if (name.trim().length < 2 || name.trim().length > 30) {
      return '이름은 2~30자로 입력해주세요.';
    }
    if ((ownerId != null && (ownerId!.isEmpty || ownerId!.length > 254)) ||
        memberIds.any((id) => id.isEmpty || id.length > 254) ||
        memberIds.toSet().length != memberIds.length) {
      return '연결할 회원을 다시 선택해주세요.';
    }
    if (sport == RankingSport.running) {
      if (distance == null ||
          seconds == null ||
          seconds! < 1 ||
          seconds! > 86399) {
        return '거리와 00:00:01~23:59:59 범위의 완주 시간을 입력해주세요.';
      }
      final today = now ?? DateTime.now();
      final lastDay = DateTime(today.year, today.month, today.day + 1);
      if (achievedAt == null ||
          achievedAt!.year < 2000 ||
          !achievedAt!.isBefore(lastDay)) {
        return '달성일은 2000년부터 오늘까지 선택해주세요.';
      }
    } else {
      if ([
        wins,
        draws,
        losses,
        goalsFor,
        goalsAgainst,
      ].any((v) => v < 0 || v > 9999)) {
        return '경기 성적은 0~9999의 정수로 입력해주세요.';
      }
      if (sport == RankingSport.basketball && draws != 0) {
        return '농구 성적은 승·패로 입력해주세요.';
      }
    }
    return null;
  }

  String get valueLabel => switch (sport) {
    RankingSport.basketball => '${winRate.toStringAsFixed(1)}%',
    RankingSport.soccer => '$points점',
    RankingSport.running => formatRunningTime(seconds ?? 0),
  };

  String get detailLabel => switch (sport) {
    RankingSport.basketball => '$wins승 $losses패 · $games경기',
    RankingSport.soccer =>
      '$wins승 $draws무 $losses패 · 득실차 ${goalDifference >= 0 ? '+' : ''}$goalDifference',
    RankingSport.running =>
      achievedAt == null ? '' : formatRankingDate(achievedAt!),
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'sport': sport.name,
    'name': name,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'distance': distance?.name,
    'seconds': seconds,
    'achievedAt': achievedAt?.toIso8601String(),
    'isDemo': isDemo,
  };

  factory SportRankingEntry.fromJson(Map<String, dynamic> j) =>
      SportRankingEntry(
        id: j['id'] as String,
        sport: RankingSport.values.byName(j['sport'] as String),
        name: j['name'] as String,
        ownerId: j['ownerId'] as String?,
        memberIds: List<String>.from(j['memberIds'] as List? ?? []),
        wins: j['wins'] as int? ?? 0,
        draws: j['draws'] as int? ?? 0,
        losses: j['losses'] as int? ?? 0,
        goalsFor: j['goalsFor'] as int? ?? 0,
        goalsAgainst: j['goalsAgainst'] as int? ?? 0,
        distance: j['distance'] == null
            ? null
            : RunningDistance.values.byName(j['distance'] as String),
        seconds: j['seconds'] as int?,
        achievedAt: j['achievedAt'] == null
            ? null
            : DateTime.parse(j['achievedAt'] as String),
        isDemo: j['isDemo'] as bool? ?? false,
      );
}

class RankedSportEntry {
  const RankedSportEntry(this.rank, this.entry, {this.tied = false});
  final int rank;
  final SportRankingEntry entry;
  final bool tied;
  String get rankLabel => '${tied ? '공동 ' : ''}$rank위';
}

int _compareScore(SportRankingEntry a, SportRankingEntry b) =>
    switch (a.sport) {
      RankingSport.basketball => (b.wins * a.games).compareTo(a.wins * b.games),
      RankingSport.soccer =>
        b.points.compareTo(a.points) != 0
            ? b.points.compareTo(a.points)
            : b.goalDifference.compareTo(a.goalDifference) != 0
            ? b.goalDifference.compareTo(a.goalDifference)
            : b.goalsFor.compareTo(a.goalsFor),
      RankingSport.running => a.seconds!.compareTo(b.seconds!),
    };

List<RankedSportEntry> rankSportEntries(
  Iterable<SportRankingEntry> source,
  RankingSport sport, {
  RunningDistance distance = RunningDistance.five,
}) {
  var entries = source
      .where(
        (e) =>
            e.sport == sport &&
            e.validate() == null &&
            (sport == RankingSport.running
                ? e.distance == distance
                : sport == RankingSport.basketball
                ? e.games >= 5
                : e.games > 0),
      )
      .toList();
  if (sport == RankingSport.running) {
    final best = <String, SportRankingEntry>{};
    for (final e in entries) {
      // Unlinked records are independent runners; linked records share one PB.
      final key = e.ownerId == null ? 'record:${e.id}' : 'account:${e.ownerId}';
      final old = best[key];
      if (old == null ||
          (old.isDemo && !e.isDemo) ||
          (old.isDemo == e.isDemo &&
              (e.seconds! < old.seconds! ||
                  (e.seconds == old.seconds &&
                      e.achievedAt!.isBefore(old.achievedAt!))))) {
        best[key] = e;
      }
    }
    entries = best.values.toList();
  }
  entries.sort((a, b) {
    final score = _compareScore(a, b);
    return score != 0 ? score : a.id.compareTo(b.id);
  });
  var rank = 1;
  return [
    for (var i = 0; i < entries.length; i++)
      RankedSportEntry(
        rank = i > 0 && _compareScore(entries[i - 1], entries[i]) == 0
            ? rank
            : i + 1,
        entries[i],
        tied:
            (i > 0 && _compareScore(entries[i - 1], entries[i]) == 0) ||
            (i + 1 < entries.length &&
                _compareScore(entries[i], entries[i + 1]) == 0),
      ),
  ];
}

String formatRunningTime(int seconds) {
  final m = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600 ? '${seconds ~/ 3600}:$m:$s' : '$m:$s';
}

int? parseRunningTime(String value) {
  if (!RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(value.trim())) return null;
  final parts = value.trim().split(':').map(int.parse).toList();
  if (parts[0] > 23 || parts[1] > 59 || parts[2] > 59) return null;
  final total = parts[0] * 3600 + parts[1] * 60 + parts[2];
  return total > 0 ? total : null;
}

String formatRankingDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

String rankingRules(RankingSport sport) => switch (sport) {
  RankingSport.basketball =>
    '전체 기간 · 최소 5경기 이상인 팀을 승률순으로 비교해요. 같은 승률은 공동 순위이며 다음 순위는 건너뜁니다.',
  RankingSport.soccer =>
    '전체 기간 · 승 3점, 무 1점, 패 0점. 승점 → 득실차 → 다득점순으로 비교해요. 모두 같으면 공동 순위이며 다음 순위는 건너뜁니다. 경기 기록이 없는 팀은 집계하지 않아요.',
  RankingSport.running =>
    '전체 기간 · 거리별 개인 최고 완주 시간으로 비교해요. 계정에 연결된 기록 중 가장 빠른 기록 1개를 사용합니다. 운영자 입력 실기록이 있으면 그 계정의 예시는 제외합니다. 동일 시간은 공동 순위이며 다음 순위는 건너뜁니다.',
};

List<SportRankingEntry> demoSportRankings() => [
  for (var i = 0; i < 6; i++)
    SportRankingEntry(
      id: 'basketball-example-$i',
      sport: RankingSport.basketball,
      name: ['중앙 위너스', '블루 코트', '서울 덩커스', '레드 훕스', '우리 팀', '캠퍼스 볼'][i],
      wins: [8, 7, 6, 5, 5, 4][i],
      losses: [2, 3, 4, 4, 5, 6][i],
      memberIds: i == 4 ? ['demo-basketball'] : [],
      isDemo: true,
    ),
  for (var i = 0; i < 6; i++)
    SportRankingEntry(
      id: 'soccer-example-$i',
      sport: RankingSport.soccer,
      name: ['중앙 FC', '그린 유나이티드', '서울 킥스', '캠퍼스 FC', '우리 FC', '한강 시티'][i],
      wins: [5, 4, 4, 3, 3, 2][i],
      draws: [1, 2, 0, 2, 1, 2][i],
      losses: [1, 1, 3, 2, 3, 3][i],
      goalsFor: [18, 15, 12, 11, 10, 8][i],
      goalsAgainst: [5, 7, 8, 10, 12, 14][i],
      memberIds: i == 4 ? ['demo-soccer'] : [],
      isDemo: true,
    ),
  for (final distance in RunningDistance.values)
    for (var i = 0; i < 6; i++)
      SportRankingEntry(
        id: 'running-${distance.name}-example-$i',
        sport: RankingSport.running,
        name: ['민트러너', '런투게더', '새벽러너', '초록발걸음', '코트메이트', '한강러너'][i],
        ownerId: i == 2
            ? 'demo-running'
            : i == 4
            ? 'demo-basketball'
            : null,
        distance: distance,
        seconds:
            [1112, 1145, 1188, 1216, 1458, 1500][i] *
            [1, 2, 5, 11][distance.index],
        achievedAt: DateTime(2026, 11, 20 + i),
        isDemo: true,
      ),
];
