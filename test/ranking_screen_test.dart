import 'dart:async';
import 'dart:convert';

import 'package:exercise_assist/members/member_controller.dart';
import 'package:exercise_assist/members/member_repository.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/ranking/ranking_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';

import 'ranking_data_test.dart' show RankingTestAdmin, RankingTestStore;
import 'support/member_test_support.dart' hide tap, keyTap;
import 'support/member_test_support.dart' as member_support show tap;

class DelayedRankingStore extends RankingTestStore {
  Completer<String?>? pending;
  int reads = 0;
  @override
  Future<String?> read() {
    reads++;
    return pending?.future ?? super.read();
  }
}

Future<void> replaceRecords(
  RankingTestStore store,
  List<SportRankingEntry> records,
) async {
  final data = jsonDecode(store.value!) as Map<String, dynamic>;
  (data['operations'] as Map<String, dynamic>)['sportRankings'] = records
      .map((e) => e.toJson())
      .toList();
  store.value = jsonEncode(data);
}

Finder get rankingScroll => find
    .descendant(
      of: find.byKey(const Key('ranking-pages')),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .hitTestable()
    .first;

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (find.byKey(const Key('ranking-pages')).evaluate().isEmpty) {
    return member_support.tap(tester, finder);
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: rankingScroll);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> keyTap(WidgetTester tester, String key) =>
    tap(tester, find.byKey(Key(key)));
Future<void> rankingTop(WidgetTester tester) async {
  await tester.drag(rankingScroll, const Offset(0, 6000));
  await tester.pumpAndSettle();
}

int rankingPage(WidgetTester tester) => tester
    .widget<PageView>(find.byKey(const Key('ranking-pages')))
    .controller!
    .page!
    .round();

Future<void> swipeRanking(WidgetTester tester, {bool next = true}) async {
  await tester.drag(
    find.byKey(const Key('ranking-pages')),
    Offset(next ? -330 : 330, 0),
  );
  await tester.pumpAndSettle();
}

void expectRankingPage(WidgetTester tester, int index) {
  expect(rankingPage(tester), index);
  expect(
    find.text(
      [
        '농구 팀 랭킹',
        '5km 개인 랭킹',
        '10km 개인 랭킹',
        '하프 개인 랭킹',
        '풀 개인 랭킹',
        '축구 팀 랭킹',
      ][index],
    ),
    findsOneWidget,
  );
  final sport = index == 0
      ? 'basketball'
      : index == 5
      ? 'soccer'
      : 'running';
  expect(
    find.descendant(
      of: find.byKey(Key('ranking-sport-$sport')),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.selected == true,
      ),
    ),
    findsOneWidget,
  );
  if (index > 0 && index < 5) {
    for (final distance in RunningDistance.values) {
      expect(
        find.descendant(
          of: find.byKey(Key('ranking-distance-${distance.name}')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.selected == (distance.index == index - 1),
          ),
        ),
        findsOneWidget,
      );
    }
  } else {
    expect(find.byKey(const Key('ranking-distance-five')), findsNothing);
  }
}

void main() {
  testWidgets(
    'header stays fixed while content and selection follow a drag and cancellation',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      final core = find.byKey(const Key('ranking-header-core'));
      final indicator = find.byKey(const Key('ranking-sport-indicator'));
      final beforeHeader = tester.getRect(core);
      final beforeContent = tester.getTopLeft(find.text('농구 팀 랭킹'));
      final beforeIndicator = tester.getTopLeft(indicator);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ranking-pages'))),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(tester.getRect(core), beforeHeader);
      expect(
        tester.getTopLeft(find.text('농구 팀 랭킹')).dx,
        lessThan(beforeContent.dx),
      );
      expect(tester.getTopLeft(indicator).dx, greaterThan(beforeIndicator.dx));
      expect(
        tester.getTopLeft(indicator).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('ranking-sport-running'))).dx,
        ),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expectRankingPage(tester, 0);
      expect(tester.getRect(core), beforeHeader);
      expect(tester.getTopLeft(indicator), beforeIndicator);
      expect(find.byKey(const Key('ranking-distance-controls')), findsNothing);
      await tester.drag(
        find.byKey(const Key('ranking-sport-basketball')),
        const Offset(-330, 0),
      );
      await tester.pumpAndSettle();
      expectRankingPage(tester, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'running controls stay still between distances and collapse only at sport boundaries',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-running');
      await openApp(tester, app, location: '/ranking');
      final core = find.byKey(const Key('ranking-header-core'));
      final distances = find.byKey(const Key('ranking-distance-controls'));
      final indicator = find.byKey(const Key('ranking-sport-indicator'));
      final beforeCore = tester.getRect(core),
          beforeDistances = tester.getRect(distances);
      final beforeButtons = {
        for (final distance in RunningDistance.values)
          distance: tester.getRect(
            find.byKey(Key('ranking-distance-${distance.name}')),
          ),
      };
      final beforeIndicator = tester.getRect(indicator);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ranking-pages'))),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(tester.getRect(core), beforeCore);
      expect(tester.getRect(distances), beforeDistances);
      expect(tester.getRect(indicator), beforeIndicator);
      await gesture.moveBy(const Offset(-230, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expectRankingPage(tester, 2);
      expect(tester.getRect(distances), beforeDistances);
      for (final distance in RunningDistance.values) {
        expect(
          tester.getRect(find.byKey(Key('ranking-distance-${distance.name}'))),
          beforeButtons[distance],
        );
      }
      await keyTap(tester, 'ranking-distance-full');
      for (final distance in RunningDistance.values) {
        expect(
          tester.getRect(find.byKey(Key('ranking-distance-${distance.name}'))),
          beforeButtons[distance],
        );
      }
      final fullHeaderHeight = tester
          .getSize(find.byKey(const Key('ranking-header-viewport')))
          .height;
      final leave = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ranking-pages'))),
      );
      await leave.moveBy(const Offset(-20, 0));
      await leave.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(tester.getRect(core), beforeCore);
      expect(
        tester.getSize(find.byKey(const Key('ranking-header-viewport'))).height,
        lessThan(fullHeaderHeight),
      );
      expect(
        tester.getTopLeft(indicator).dx,
        greaterThan(beforeIndicator.left),
      );
      await leave.moveBy(const Offset(-230, 0));
      await leave.up();
      await tester.pumpAndSettle();
      expectRankingPage(tester, 5);
      expect(find.byKey(const Key('ranking-distance-controls')), findsNothing);
      expect(tester.getRect(core), beforeCore);
      await swipeRanking(tester, next: false);
      expectRankingPage(tester, 4);
      expect(tester.getRect(distances), beforeDistances);
    },
  );

  testWidgets(
    'distance indicator follows every adjacent swipe and restores a cancelled drag',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-running');
      await openApp(tester, app, location: '/ranking');
      final indicator = find.byKey(const Key('ranking-distance-indicator'));
      final sport = tester.getRect(
        find.byKey(const Key('ranking-sport-indicator')),
      );
      final buttons = [
        for (final distance in RunningDistance.values)
          tester.getRect(find.byKey(Key('ranking-distance-${distance.name}'))),
      ];
      for (final next in [true, true, true, false, false, false]) {
        final from = rankingPage(tester) - 1;
        final to = from + (next ? 1 : -1);
        final direction = next ? -1.0 : 1.0;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('ranking-pages'))),
        );
        await gesture.moveBy(Offset(20 * direction, 0));
        await gesture.moveBy(Offset(80 * direction, 0));
        await tester.pump();
        final x = tester.getTopLeft(indicator).dx;
        expect(
          x,
          greaterThan(
            buttons[from].left < buttons[to].left
                ? buttons[from].left
                : buttons[to].left,
          ),
        );
        expect(
          x,
          lessThan(
            buttons[from].left > buttons[to].left
                ? buttons[from].left
                : buttons[to].left,
          ),
        );
        expect(
          tester.getRect(find.byKey(const Key('ranking-sport-indicator'))),
          sport,
        );
        for (final distance in RunningDistance.values) {
          expect(
            tester.getRect(
              find.byKey(Key('ranking-distance-${distance.name}')),
            ),
            buttons[distance.index],
          );
        }
        await gesture.moveBy(Offset(230 * direction, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expectRankingPage(tester, to + 1);
        expect(tester.getRect(indicator), buttons[to]);
      }
      final cancel = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ranking-pages'))),
      );
      await cancel.moveBy(const Offset(-20, 0));
      await cancel.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(tester.getTopLeft(indicator).dx, greaterThan(buttons[0].left));
      await cancel.moveBy(const Offset(100, 0));
      await tester.pump();
      await cancel.up();
      await tester.pumpAndSettle();
      expectRankingPage(tester, 1);
      expect(tester.getRect(indicator), buttons[0]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('distance button animates the green indicator for 180ms', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-running');
    await openApp(tester, app, location: '/ranking');
    final indicator = find.byKey(const Key('ranking-distance-indicator'));
    final start = tester.getRect(indicator);
    final end = tester.getRect(find.byKey(const Key('ranking-distance-full')));
    await tester.tap(find.byKey(const Key('ranking-distance-full')));
    await tester.pump();
    expectRankingPage(tester, 4);
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getTopLeft(indicator).dx, greaterThan(start.left));
    expect(tester.getTopLeft(indicator).dx, lessThan(end.left));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();
    expect(tester.getRect(indicator), end);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'direct buttons jump content and animate only header selection for 180ms',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      final indicator = find.byKey(const Key('ranking-sport-indicator'));
      final start = tester.getTopLeft(indicator).dx;
      await tester.tap(find.byKey(const Key('ranking-sport-soccer')));
      await tester.pump();
      expect(rankingPage(tester), 5);
      expect(find.text('축구 팀 랭킹'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 90));
      final middle = tester.getTopLeft(indicator).dx;
      final end = tester
          .getTopLeft(find.byKey(const Key('ranking-sport-soccer')))
          .dx;
      expect(middle, greaterThan(start));
      expect(middle, lessThan(end));
      expect(find.byKey(const Key('ranking-distance-controls')), findsNothing);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(indicator).dx, closeTo(end, .01));
      await tester.tap(find.byKey(const Key('ranking-sport-running')));
      await tester.pump();
      expect(rankingPage(tester), 1);
      await tester.pump(const Duration(milliseconds: 90));
      final fade = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(const Key('ranking-distance-controls')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(fade.opacity, greaterThan(0));
      expect(fade.opacity, lessThan(1));
      await tester.pumpAndSettle();
      expectRankingPage(tester, 1);
    },
  );

  testWidgets(
    'reduced motion applies header selection and distance controls immediately',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      await tester.tap(find.byKey(const Key('ranking-sport-running')));
      await tester.pump();
      expectRankingPage(tester, 1);
      expect(
        tester.getTopLeft(find.byKey(const Key('ranking-sport-indicator'))).dx,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('ranking-sport-running'))).dx,
          .01,
        ),
      );
      expect(
        tester.getRect(find.byKey(const Key('ranking-distance-indicator'))),
        tester.getRect(find.byKey(const Key('ranking-distance-five'))),
      );
      await tester.tap(find.byKey(const Key('ranking-distance-full')));
      await tester.pump();
      expectRankingPage(tester, 4);
      expect(
        tester.getRect(find.byKey(const Key('ranking-distance-indicator'))),
        tester.getRect(find.byKey(const Key('ranking-distance-full'))),
      );
      await keyTap(tester, 'ranking-sport-soccer');
      expect(find.byKey(const Key('ranking-distance-controls')), findsNothing);
      await swipeRanking(tester, next: false);
      expectRankingPage(tester, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short landscape header is bounded and every selector remains reachable',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(
        tester,
        app,
        location: '/ranking',
        size: const Size(850, 320),
        scale: 2,
      );
      double headerHeight() => tester
          .getSize(find.byKey(const Key('ranking-header-viewport')))
          .height;
      double contentHeight() =>
          tester.getSize(find.byKey(const Key('ranking-pages'))).height;
      expect(
        headerHeight(),
        lessThanOrEqualTo((headerHeight() + contentHeight()) * .45 + .01),
      );
      expect(contentHeight(), greaterThan(0));
      await keyTap(tester, 'ranking-sport-running');
      await keyTap(tester, 'ranking-distance-full');
      expect(rankingPage(tester), 4);
      expect(
        find.byKey(const Key('ranking-distance-full')).hitTestable(),
        findsOneWidget,
      );
      expect(
        headerHeight(),
        lessThanOrEqualTo((headerHeight() + contentHeight()) * .45 + .01),
      );
      await keyTap(tester, 'ranking-sport-soccer');
      expect(rankingPage(tester), 5);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mouse dragging supports the same page order in web previews', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    await openApp(tester, app, location: '/ranking');
    await tester.drag(
      find.byKey(const Key('ranking-pages')),
      const Offset(-330, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expectRankingPage(tester, 1);
    await tester.drag(
      find.byKey(const Key('ranking-pages')),
      const Offset(330, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expectRankingPage(tester, 0);
  });
  testWidgets(
    'six pages swipe both ways, synchronize selectors and stop at each end without reads',
    (tester) async {
      final store = DelayedRankingStore(), app = makeApp(store: store);
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      final reads = store.reads;
      expectRankingPage(tester, 0);
      for (var index = 1; index < 6; index++) {
        await swipeRanking(tester);
        expectRankingPage(tester, index);
      }
      await swipeRanking(tester);
      expectRankingPage(tester, 5);
      for (var index = 4; index >= 0; index--) {
        await swipeRanking(tester, next: false);
        expectRankingPage(tester, index);
      }
      await swipeRanking(tester, next: false);
      expectRankingPage(tester, 0);
      expect(store.reads, reads);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct selection skips pages and running remembers its last distance',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      await keyTap(tester, 'ranking-sport-soccer');
      expectRankingPage(tester, 5);
      await keyTap(tester, 'ranking-sport-running');
      expectRankingPage(tester, 1);
      await keyTap(tester, 'ranking-distance-full');
      expectRankingPage(tester, 4);
      await keyTap(tester, 'ranking-sport-basketball');
      expectRankingPage(tester, 0);
      await keyTap(tester, 'ranking-sport-running');
      expectRankingPage(tester, 4);
      await keyTap(tester, 'ranking-distance-half');
      await keyTap(tester, 'ranking-sport-soccer');
      await keyTap(tester, 'ranking-sport-running');
      expectRankingPage(tester, 3);
      await swipeRanking(tester, next: false);
      expectRankingPage(tester, 2);
      await keyTap(tester, 'ranking-sport-soccer');
      await keyTap(tester, 'ranking-sport-running');
      expectRankingPage(tester, 2);
    },
  );

  testWidgets(
    'each page restores its vertical position and account changes reset page storage',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      double pixels() =>
          tester.state<ScrollableState>(rankingScroll).position.pixels;
      await tester.drag(rankingScroll, const Offset(0, -350));
      await tester.pumpAndSettle();
      final basketballOffset = pixels();
      expect(basketballOffset, greaterThan(0));
      expect(rankingPage(tester), 0);
      await swipeRanking(tester);
      expect(pixels(), 0);
      await tester.drag(rankingScroll, const Offset(0, -250));
      await tester.pumpAndSettle();
      final runningOffset = pixels();
      expect(runningOffset, greaterThan(0));
      expect(rankingPage(tester), 1);
      await swipeRanking(tester, next: false);
      expect(pixels(), closeTo(basketballOffset, 1));
      await swipeRanking(tester);
      expect(pixels(), closeTo(runningOffset, 1));
      await swipeRanking(tester);
      expect(pixels(), 0);
      await app.members.useDemo('demo-soccer');
      await tester.pumpAndSettle();
      expectRankingPage(tester, 5);
      expect(pixels(), 0);
      await app.members.useDemo('demo-basketball');
      await tester.pumpAndSettle();
      expectRankingPage(tester, 0);
      expect(pixels(), 0);
    },
  );

  testWidgets(
    'empty pages still swipe and pending team guidance is preserved',
    (tester) async {
      final store = RankingTestStore(), app = makeApp(store: store);
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await replaceRecords(store, []);
      await openApp(tester, app, location: '/ranking');
      for (var index = 0; index < 6; index++) {
        expectRankingPage(tester, index);
        expect(find.byKey(const Key('ranking-empty')), findsOneWidget);
        expect(find.text('나머지 순위'), findsNothing);
        if (index < 5) await swipeRanking(tester);
      }
      await keyTap(tester, 'ranking-sport-basketball');
      await replaceRecords(store, [
        SportRankingEntry(
          id: 'pending-team',
          name: '집계 대기 팀',
          sport: RankingSport.basketball,
          wins: 4,
          memberIds: ['demo-basketball'],
        ),
      ]);
      await keyTap(tester, 'ranking-refresh');
      await keyTap(tester, 'ranking-mine-title');
      expect(find.textContaining('최소 5경기부터 순위에 포함돼요.'), findsOneWidget);
      expect(find.byKey(const Key('ranking-row-pending-team')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'podium includes row details and remainder excludes its three entries',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-running');
      await openApp(tester, app, location: '/ranking');
      for (final sport in RankingSport.values) {
        await rankingTop(tester);
        await keyTap(tester, 'ranking-sport-${sport.name}');
        final rows = rankSportEntries(
          app.members.operations.sportRankings,
          sport,
        );
        for (final row in rows.take(3)) {
          final card = find.byKey(Key('ranking-podium-${row.entry.id}'));
          expect(
            find.descendant(of: card, matching: find.text(row.rankLabel)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: card, matching: find.text(row.entry.name)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text(row.entry.valueLabel),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text(row.entry.detailLabel),
            ),
            findsOneWidget,
          );
          expect(find.byKey(Key('ranking-row-${row.entry.id}')), findsNothing);
        }
        await keyTap(tester, 'ranking-row-${rows[3].entry.id}');
        expect(find.text('나머지 순위'), findsOneWidget);
        if (sport == RankingSport.running) {
          await rankingTop(tester);
          expect(find.text('내 기록'), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'one to three entries hide remainder; joint places stay unchanged',
    (tester) async {
      final store = RankingTestStore(), app = makeApp(store: store);
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      List<SportRankingEntry> tied(int count) => [
        for (var i = 0; i < count; i++)
          SportRankingEntry(
            id: 'joint-$i',
            name: '공동 팀 $i',
            sport: RankingSport.basketball,
            wins: 5,
            losses: 5,
            memberIds: i == 0 ? ['demo-basketball'] : [],
          ),
      ];
      await replaceRecords(store, tied(1));
      await openApp(tester, app, location: '/ranking');
      for (var count = 1; count <= 4; count++) {
        if (count > 1) {
          await replaceRecords(store, tied(count));
          await rankingTop(tester);
          await keyTap(tester, 'ranking-refresh');
        }
        expect(find.text('나머지 순위'), count > 3 ? findsOneWidget : findsNothing);
        expect(find.byKey(const Key('ranking-podium-joint-0')), findsOneWidget);
        expect(find.text('내 팀'), findsOneWidget);
        expect(find.byKey(const Key('ranking-row-joint-0')), findsNothing);
        if (count == 4) {
          await keyTap(tester, 'ranking-row-joint-3');
          expect(find.text('공동 1위 · 공동 팀 3'), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'operator team totals, account link, edit and confirmed deletion',
    (tester) async {
      final store = RankingTestStore();
      final app = AppState(
        members: MemberController(
          MemberRepository(
            store: store,
            hasher: TestHasher(),
            adminGateway: RankingTestAdmin(),
          ),
        ),
      );
      await app.members.initialize();
      await app.members.loginOperator('test');
      await openApp(
        tester,
        app,
        location: '/admin',
        size: const Size(320, 850),
        scale: 2,
      );
      await keyTap(tester, 'admin-section-2');
      await keyTap(tester, 'admin-sport-rankings');
      await keyTap(tester, 'manage-sport-soccer');
      await keyTap(tester, 'sport-rank-add');
      await tester.enterText(find.byKey(const Key('sport-rank-name')), '검증 FC');
      await tester.enterText(find.byKey(const Key('sport-rank-wins')), '5');
      await tester.enterText(find.byKey(const Key('sport-rank-draws')), '2');
      await tester.enterText(find.byKey(const Key('sport-rank-losses')), '1');
      await tester.enterText(
        find.byKey(const Key('sport-rank-goalsFor')),
        '14',
      );
      await tester.enterText(
        find.byKey(const Key('sport-rank-goalsAgainst')),
        '5',
      );
      await keyTap(tester, 'sport-rank-member-demo-soccer');
      await keyTap(tester, 'sport-rank-save');
      final saved = app.members.operations.sportRankings.singleWhere(
        (e) => e.name == '검증 FC',
      );
      expect(saved.points, 17);
      expect(saved.goalDifference, 9);
      expect(saved.belongsTo('demo-soccer'), isTrue);
      final managerScroll = find
          .descendant(
            of: find.byKey(const Key('sport-rank-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(Key('sport-rank-edit-${saved.id}')),
        400,
        scrollable: managerScroll,
      );
      await keyTap(tester, 'sport-rank-edit-${saved.id}');
      await tester.enterText(find.byKey(const Key('sport-rank-wins')), '6');
      await keyTap(tester, 'sport-rank-save');
      expect(
        app.members.operations.sportRankings
            .singleWhere((e) => e.id == saved.id)
            .points,
        20,
      );
      await keyTap(tester, 'sport-rank-delete-${saved.id}');
      await tap(tester, find.widgetWithText(FilledButton, '삭제'));
      expect(
        app.members.operations.sportRankings.any((e) => e.id == saved.id),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sport tabs, all four distances, rules and linked personal rankings',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      expect(find.text('농구 팀 랭킹'), findsOneWidget);
      expect(find.byKey(const Key('ranking-distance-five')), findsNothing);
      await keyTap(tester, 'ranking-rules');
      expect(find.textContaining('같은 승률은 공동 순위'), findsOneWidget);
      await tap(tester, find.text('확인'));
      await keyTap(tester, 'ranking-mine-basketball-example-4');
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('ranking-mine-basketball-example-4')),
            )
            .data,
        contains('5위 · 우리 팀'),
      );
      await rankingTop(tester);
      await keyTap(tester, 'ranking-sport-running');
      for (final d in RunningDistance.values) {
        await keyTap(tester, 'ranking-distance-${d.name}');
        expect(find.text('${d.label} 개인 랭킹'), findsOneWidget);
        await keyTap(tester, 'ranking-mine-running-${d.name}-example-4');
        expect(tester.takeException(), isNull);
        await rankingTop(tester);
      }
      await keyTap(tester, 'ranking-sport-soccer');
      expect(find.text('축구 팀 랭킹'), findsOneWidget);
      expect(find.byKey(const Key('ranking-distance-full')), findsNothing);
      await keyTap(tester, 'ranking-mine-title');
      expect(find.text('내 계정에 연결된 팀 성적이 없어요.'), findsOneWidget);
    },
  );

  testWidgets(
    'read failure retains rows and retry recovers; loading prevents duplicate reads',
    (tester) async {
      final store = DelayedRankingStore();
      final actual = makeApp(store: store);
      await actual.members.initialize();
      await actual.members.useDemo('demo-basketball');
      await openApp(tester, actual, location: '/ranking');
      final before = store.reads;
      store.pending = Completer<String?>();
      await tester.tap(find.byKey(const Key('ranking-refresh')));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('ranking-refresh')))
            .onPressed,
        isNull,
      );
      expect(store.reads, before + 1);
      expect(find.text('중앙 위너스'), findsWidgets);
      store.pending!.completeError(StateError('connection interrupted'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-load-error')), findsOneWidget);
      expect(find.text('중앙 위너스'), findsWidgets);
      store.pending = null;
      await tap(tester, find.text('다시 시도'));
      expect(find.byKey(const Key('ranking-load-error')), findsNothing);
      expect(store.reads, before + 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty ranking and no linked record have clear guidance', (
    tester,
  ) async {
    final store = RankingTestStore();
    final actual = makeApp(store: store);
    await actual.members.initialize();
    await actual.members.useDemo('demo-basketball');
    await replaceRecords(store, []);
    await openApp(tester, actual, location: '/ranking');
    expect(find.byKey(const Key('ranking-empty')), findsOneWidget);
    await keyTap(tester, 'ranking-mine-title');
    expect(find.text('내 계정에 연결된 팀 성적이 없어요.'), findsOneWidget);
    await rankingTop(tester);
    await keyTap(tester, 'ranking-sport-running');
    await keyTap(tester, 'ranking-mine-title');
    expect(find.text('이 거리에서 내 계정에 연결된 완주 기록이 없어요.'), findsOneWidget);
  });

  testWidgets(
    'account switching never reuses another account personal ranking',
    (tester) async {
      final app = makeApp();
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await openApp(tester, app, location: '/ranking');
      await keyTap(tester, 'ranking-mine-basketball-example-4');
      await app.members.useDemo('demo-soccer');
      await tester.pumpAndSettle();
      await keyTap(tester, 'ranking-mine-soccer-example-4');
      expect(
        find.byKey(const Key('ranking-mine-basketball-example-4')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('ranking-mine-soccer-example-4')),
            )
            .data,
        contains('5위 · 우리 FC'),
      );
    },
  );

  for (final size in [
    const Size(320, 850),
    const Size(850, 320),
    const Size(1100, 850),
  ]) {
    testWidgets('large text dark layout, long names and rotation at $size', (
      tester,
    ) async {
      final store = RankingTestStore(), app = makeApp(store: store);
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      app.toggleTheme();
      await replaceRecords(store, [
        SportRankingEntry(
          id: 'long',
          sport: RankingSport.basketball,
          name: '아주긴이름을가진농구팀과함께운동하는즐거운우리친구들',
          wins: 5,
          memberIds: ['demo-basketball'],
        ),
        ...demoSportRankings().where((e) => e.sport == RankingSport.running),
      ]);
      await openApp(tester, app, location: '/ranking', size: size, scale: 2);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        await tester.drag(rankingScroll, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await rankingTop(tester);
      await keyTap(tester, 'ranking-sport-running');
      await keyTap(tester, 'ranking-distance-full');
      for (var i = 0; i < 5; i++) {
        await tester.drag(rankingScroll, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = Size(size.height, size.width);
      await tester.pumpAndSettle();
      await rankingTop(tester);
      await keyTap(tester, 'ranking-title');
      expect(find.text('풀 개인 랭킹'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'operator creates running result, validation, failed save and retry',
    (tester) async {
      final store = RankingTestStore();
      final app = AppState(
        members: MemberController(
          MemberRepository(
            store: store,
            hasher: TestHasher(),
            adminGateway: RankingTestAdmin(),
          ),
        ),
      );
      await app.members.initialize();
      await app.members.useDemo('demo-running');
      await app.members.loginOperator('test');
      final router = await openApp(tester, app, location: '/admin');
      await keyTap(tester, 'admin-section-2');
      await keyTap(tester, 'admin-sport-rankings');
      await keyTap(tester, 'manage-sport-running');
      await keyTap(tester, 'sport-rank-add');
      await tester.enterText(find.byKey(const Key('sport-rank-name')), '검증러너');
      await tester.enterText(
        find.byKey(const Key('sport-rank-time')),
        '00:60:00',
      );
      await tester.enterText(
        find.byKey(const Key('sport-rank-date')),
        '2026-02-30',
      );
      await keyTap(tester, 'sport-rank-save');
      expect(find.text('00:00:01~23:59:59로 입력해주세요.'), findsOneWidget);
      expect(find.textContaining('올바른 날짜'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('sport-rank-time')),
        '00:17:30',
      );
      await tester.enterText(
        find.byKey(const Key('sport-rank-date')),
        '2026-11-25',
      );
      await tap(tester, find.byKey(const Key('sport-rank-owner')));
      await tap(tester, find.text('새벽러너 (DEMO)').last);
      store.failWrite = true;
      await keyTap(tester, 'sport-rank-save');
      expect(find.byKey(const Key('sport-rank-save-error')), findsOneWidget);
      expect(
        app.members.operations.sportRankings.any((e) => e.name == '검증러너'),
        isFalse,
      );
      store.failWrite = false;
      await keyTap(tester, 'sport-rank-save');
      final saved = app.members.operations.sportRankings.singleWhere(
        (e) => e.name == '검증러너',
      );
      expect(saved.ownerId, 'demo-running');
      expect(saved.seconds, 1050);
      await tap(tester, find.byType(CloseButton).last);
      await tester.pumpAndSettle();
      await app.members.useDemo('demo-running');
      router.go('/ranking');
      await tester.pumpAndSettle();
      await keyTap(tester, 'ranking-mine-${saved.id}');
      expect(
        tester.widget<Text>(find.byKey(Key('ranking-mine-${saved.id}'))).data,
        contains('1위 · 검증러너'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
