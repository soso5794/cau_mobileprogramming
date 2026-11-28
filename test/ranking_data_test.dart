import 'dart:convert';

import 'package:exercise_assist/admin/admin_gateway.dart';
import 'package:exercise_assist/admin/operations_data.dart';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/ranking/ranking_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/member_test_support.dart';

class RankingTestAdmin implements AdminGateway {
  bool valid = true;
  @override
  Future<String> login(String password) async => 'ranking-test-token';
  @override
  Future<void> verify(String token) async {
    if (!valid) throw const MemberFailure('인증이 만료됐어요.');
  }

  @override
  Future<void> logout(String token) async {}
  @override
  void close() {}
}

class RankingTestStore extends MemoryMemberStore {
  bool failRead = false, failWrite = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return super.read();
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('write failed');
    return super.write(value);
  }
}

SportRankingEntry team(
  String id, {
  RankingSport sport = RankingSport.basketball,
  int wins = 5,
  int losses = 5,
  int draws = 0,
  int gf = 0,
  int ga = 0,
  List<String> members = const [],
}) => SportRankingEntry(
  id: id,
  sport: sport,
  name: '팀 $id',
  wins: wins,
  losses: losses,
  draws: draws,
  goalsFor: gf,
  goalsAgainst: ga,
  memberIds: members,
);

SportRankingEntry run(
  String id,
  int seconds, {
  String? owner = 'runner',
  RunningDistance distance = RunningDistance.five,
  int day = 20,
}) => SportRankingEntry(
  id: id,
  sport: RankingSport.running,
  name: '러너 $id',
  ownerId: owner,
  distance: distance,
  seconds: seconds,
  achievedAt: DateTime(2026, 11, day),
);

void main() {
  test(
    'authentication connection loss leaves standings intact and retry succeeds',
    () async {
      var online = true;
      final gateway = HttpAdminGateway(
        client: MockClient((request) async {
          if (!online) throw http.ClientException('connection lost');
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/login')
                  ? {'email': operatorEmail, 'token': 'a' * 64}
                  : {'email': operatorEmail, 'authorized': true},
            ),
            200,
          );
        }),
      );
      addTearDown(gateway.close);
      final store = RankingTestStore();
      final r = MemberRepository(
        store: store,
        hasher: TestHasher(),
        adminGateway: gateway,
      );
      await r.loginOperator('test');
      final before = store.value;
      online = false;
      await expectLater(
        r.saveSportRanking(team('network')),
        throwsA(
          isA<MemberFailure>().having(
            (e) => e.message,
            'message',
            contains('연결'),
          ),
        ),
      );
      expect(store.value, before);
      expect(r.operations.logs, isEmpty);
      online = true;
      await r.saveSportRanking(team('network'));
      expect(r.operations.sportRankings.any((e) => e.id == 'network'), isTrue);
    },
  );
  test(
    'legacy operations remain readable; explicit empty sports stay empty',
    () {
      final old = OperationsData().toJson()..remove('sportRankings');
      final migrated = OperationsData.fromJson(old);
      expect(migrated.rankings.length, 4);
      expect(migrated.sortedRankings.first.name, '민트러너');
      expect(migrated.sportRankings.length, 36);
      final empty = OperationsData(sportRankings: []);
      expect(OperationsData.fromJson(empty.toJson()).sportRankings, isEmpty);
      expect(empty.changed('모집 저장', '모집').sportRankings, isEmpty);
    },
  );

  test('all sport records and identity links survive JSON round trip', () {
    for (final entry in demoSportRankings()) {
      final restored = SportRankingEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), entry.toJson());
      expect(restored.validate(), isNull);
    }
  });

  test('basketball eligibility, exact win rate, shared ranks and gaps', () {
    final rows = rankSportEntries([
      team('a', wins: 1, losses: 0), // Below five games.
      team('b', wins: 6, losses: 4),
      team('c', wins: 3, losses: 2),
      team('d', wins: 2, losses: 4),
      team('e', wins: 8, losses: 2),
    ], RankingSport.basketball);
    expect(rows.map((r) => r.entry.id), ['e', 'b', 'c', 'd']);
    expect(rows.map((r) => r.rank), [1, 2, 2, 4]);
    expect(rows[1].rankLabel, '공동 2위');
    expect(rows[2].entry.winRate, 60);
    expect(
      rankSportEntries([
        team('zero', wins: 0, losses: 0),
      ], RankingSport.basketball),
      isEmpty,
    );
  });

  test('soccer points, goal difference, goals scored and shared ranks', () {
    SportRankingEntry soccer(String id, int gf, int ga, {int wins = 3}) => team(
      id,
      sport: RankingSport.soccer,
      wins: wins,
      draws: 1,
      losses: 1,
      gf: gf,
      ga: ga,
    );
    final rows = rankSportEntries([
      soccer('a', 5, 3),
      soccer('b', 9, 5),
      soccer('c', 8, 4),
      soccer('d', 8, 4),
      soccer('e', 1, 1, wins: 4),
      team('zero', sport: RankingSport.soccer, wins: 0, losses: 0),
    ], RankingSport.soccer);
    expect(rows.map((r) => r.entry.id), ['e', 'b', 'c', 'd', 'a']);
    expect(rows.map((r) => r.rank), [1, 2, 3, 3, 5]);
    expect(rows.first.entry.points, 13);
  });

  test(
    'running selects one PB per account and distance, with joint places',
    () {
      final records = [
        run('slow', 1300),
        run('fast', 1000),
        run('same-later', 1000, day: 23),
        run('another', 1000, owner: 'other'),
        run('last', 1500, owner: 'last'),
        run('10k', 2000, distance: RunningDistance.ten),
      ];
      final rows = rankSportEntries(records, RankingSport.running);
      expect(rows.map((r) => r.entry.id), ['another', 'fast', 'last']);
      expect(rows.map((r) => r.rank), [1, 1, 3]);
      expect(rows[1].entry.belongsTo('runner'), isTrue);
      expect(
        rankSportEntries(
          records,
          RankingSport.running,
          distance: RunningDistance.ten,
        ).single.entry.id,
        '10k',
      );
      for (final d in RunningDistance.values) {
        expect(
          rankSportEntries(
            demoSportRankings(),
            RankingSport.running,
            distance: d,
          ).length,
          6,
        );
      }
    },
  );

  test('unlinked runners are independent; names never establish identity', () {
    final rows = rankSportEntries([
      run('one', 1100, owner: null),
      run('two', 1200, owner: null),
    ], RankingSport.running);
    expect(rows.length, 2);
    expect(rows.every((r) => !r.entry.belongsTo('러너 one')), isTrue);
    expect(team('mine', members: ['member']).belongsTo('member'), isTrue);
    expect(team('mine', members: ['member']).belongsTo(null), isFalse);
  });

  test(
    'real running results replace account examples without duplicate personal ranks',
    () {
      final real = run('real', 1400, owner: 'demo-running');
      for (final records in [
        [...demoSportRankings(), real],
        [real, ...demoSportRankings()],
      ]) {
        final mine = rankSportEntries(
          records,
          RankingSport.running,
        ).where((r) => r.entry.belongsTo('demo-running')).toList();
        expect(mine.length, 1);
        expect(mine.single.entry.id, 'real');
      }
    },
  );

  test('time format, bounds and invalid values are rejected', () {
    expect(parseRunningTime('00:18:32'), 1112);
    expect(parseRunningTime('23:59:59'), 86399);
    for (final bad in [
      '00:00:00',
      '24:00:00',
      '00:60:00',
      '00:00:60',
      '18:32',
      '-1:00:00',
      'NaN',
    ]) {
      expect(parseRunningTime(bad), isNull, reason: bad);
    }
    expect(formatRunningTime(1112), '18:32');
    expect(formatRunningTime(3661), '1:01:01');
    expect(run('bad', 0).validate(), isNotNull);
    expect(team('bad', wins: -1).validate(), isNotNull);
    expect(team('bad', wins: 10000).validate(), isNotNull);
    expect(team('bad', draws: 1).validate(), isNotNull);
    expect(run('future', 1200).validate(now: DateTime(2026, 1)), isNotNull);
    expect(
      SportRankingEntry(
        id: 'name',
        sport: RankingSport.basketball,
        name: '가' * 31,
      ).validate(),
      isNotNull,
    );
  });

  test(
    'operator CRUD, PB recomputation and persistence preserve weekly data',
    () async {
      final store = RankingTestStore();
      final r = MemberRepository(
        store: store,
        hasher: TestHasher(),
        adminGateway: RankingTestAdmin(),
      );
      await r.useDemo('demo-running');
      await r.loginOperator('test');
      final weekly = r.operations.rankings.map((e) => e.toJson()).toList();
      await r.saveSportRanking(run('manual-1', 900, owner: 'demo-running'));
      await r.saveSportRanking(run('manual-2', 950, owner: 'demo-running'));
      expect(
        rankSportEntries(
          r.operations.sportRankings.where((e) => !e.isDemo),
          RankingSport.running,
        ).single.entry.seconds,
        900,
      );
      await r.deleteSportRanking('manual-1');
      expect(
        rankSportEntries(
          r.operations.sportRankings.where((e) => !e.isDemo),
          RankingSport.running,
        ).single.entry.seconds,
        950,
      );
      final restored = MemberRepository(
        store: store,
        hasher: TestHasher(),
        adminGateway: RankingTestAdmin(),
      );
      await restored.restore();
      expect(
        restored.operations.sportRankings.any((e) => e.id == 'manual-2'),
        isTrue,
      );
      expect(
        restored.operations.rankings.map((e) => e.toJson()).toList(),
        weekly,
      );
    },
  );

  test(
    'unauthorized, expired, invalid identity and failed writes keep old data',
    () async {
      final store = RankingTestStore(), auth = RankingTestAdmin();
      final r = MemberRepository(
        store: store,
        hasher: TestHasher(),
        adminGateway: auth,
      );
      await r.useDemo('demo-basketball');
      await expectLater(
        r.saveSportRanking(team('new')),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.deleteSportRanking('basketball-example-0'),
        throwsA(isA<MemberFailure>()),
      );
      await r.loginOperator('test');
      final before = store.value;
      await expectLater(
        r.saveSportRanking(team('bad', members: ['missing'])),
        throwsA(isA<MemberFailure>()),
      );
      await expectLater(
        r.saveSportRanking(team('bad', wins: -1)),
        throwsA(isA<MemberFailure>()),
      );
      auth.valid = false;
      await expectLater(
        r.saveSportRanking(team('new')),
        throwsA(isA<MemberFailure>()),
      );
      auth.valid = true;
      store.failWrite = true;
      await expectLater(r.saveSportRanking(team('new')), throwsStateError);
      expect(store.value, before);
      expect(r.operations.logs, isEmpty);
      expect(r.operations.sportRankings.length, 36);
    },
  );

  test(
    'refresh recovers after failed read and never replaces cached data on error',
    () async {
      final store = RankingTestStore();
      final r = MemberRepository(
        store: store,
        hasher: TestHasher(),
        adminGateway: RankingTestAdmin(),
      );
      await r.useDemo('demo-basketball');
      final before = r.operations;
      store.failRead = true;
      await expectLater(r.refreshRankings(), throwsStateError);
      expect(r.operations, same(before));
      store.failRead = false;
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      (data['operations'] as Map<String, dynamic>)['sportRankings'] =
          <Object>[];
      store.value = jsonEncode(data);
      await r.refreshRankings();
      expect(r.operations.sportRankings, isEmpty);
      expect(r.current!.id, 'demo-basketball');
    },
  );
}
