import 'dart:async';
import 'dart:convert';
import 'package:exercise_assist/ai/ai_gateway.dart';
import 'package:exercise_assist/calendar/workout_calendar.dart';
import 'package:exercise_assist/calendar/workout_event.dart';
import 'package:exercise_assist/members/member_models.dart';
import 'package:exercise_assist/members/member_store.dart';
import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/screens/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'support/member_test_support.dart';

WorkoutEvent event(String id, DateTime start, {int minutes = 60}) =>
    WorkoutEvent(
      id: id,
      title: '농구 연습',
      sport: '농구',
      start: start,
      minutes: minutes,
    );

class FakeAi implements AiGateway {
  final calls = <List<AiTurn>>[];
  final pending = <Completer<String>>[];
  @override
  Future<String> answer(List<AiTurn> history) {
    calls.add(history);
    final c = Completer<String>();
    pending.add(c);
    return c.future;
  }

  @override
  void close() {}
}

void main() {
  test(
    'legacy accounts default to empty calendar; events survive restart and are isolated',
    () async {
      final store = MemoryMemberStore();
      final app = makeApp(store: store);
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      final original = app.members.profile!;
      final old = original.toJson()..remove('events');
      expect(MemberProfile.fromJson(old).events, isEmpty);
      final e = event('one', DateTime(2028, 2, 29, 18));
      expect(await app.members.saveEvent(e, ownerId: original.id), isTrue);
      final restored = makeApp(store: store);
      await restored.members.initialize();
      expect(
        restored.members.profile!.events.single.start,
        DateTime(2028, 2, 29, 18),
      );
      await restored.members.useDemo('demo-running');
      expect(restored.members.profile!.events, isEmpty);
      expect(
        await restored.members.saveEvent(e, ownerId: original.id),
        isFalse,
      );
      await restored.members.useDemo('demo-basketball');
      await restored.members.saveEvent(
        e.withCompleted(true),
        ownerId: original.id,
      );
      expect(restored.members.profile!.events.single.completed, isTrue);
      await restored.members.deleteEvent('one', ownerId: original.id);
      expect(restored.members.profile!.events, isEmpty);
      app.dispose();
      restored.dispose();
    },
  );
  test(
    'overlap is exclusive at endpoints, includes cross-midnight, rejects invalid duration',
    () {
      final a = event('a', DateTime(2026, 11, 18, 23, 30));
      expect(a.overlaps(event('b', DateTime(2026, 11, 19))), isTrue);
      expect(a.overlaps(event('b', DateTime(2026, 11, 19, 0, 30))), isFalse);
      expect(a.overlaps(a), isFalse);
      expect(event('bad', DateTime.now(), minutes: 0).validate(), isNotNull);
    },
  );
  test(
    'HTTP gateway sends only explicit history and returns provider text',
    () async {
      final g = HttpAiGateway(
        baseUrl: Uri.parse('http://localhost:8787'),
        client: MockClient((r) async {
          expect(r.url.path, '/api/chat');
          expect(jsonDecode(r.body), {
            'messages': [
              {'role': 'user', 'content': '농구'},
            ],
          });
          expect(r.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            jsonEncode({'reply': '패스를 연습하세요'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(await g.answer([const AiTurn('농구', fromUser: true)]), '패스를 연습하세요');
      g.close();
    },
  );
  for (final status in [400, 429, 503, 504]) {
    test('HTTP $status becomes a user-facing error', () async {
      final g = HttpAiGateway(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        g.answer([const AiTurn('질문', fromUser: true)]),
        throwsA(isA<AiFailure>()),
      );
      g.close();
    });
  }
  test('malformed response and transport timeout handled', () async {
    for (final body in ['bad json', '{}', '{"reply":""}']) {
      final g = HttpAiGateway(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(g.answer([]), throwsA(isA<AiFailure>()));
      g.close();
    }
    final g = HttpAiGateway(
      timeout: Duration.zero,
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(g.answer([]), throwsA(isA<AiFailure>()));
    g.close();
  });
  testWidgets('calendar handles leap month, CRUD and completion', (
    tester,
  ) async {
    final app = makeApp();
    await app.members.initialize();
    await app.members.useDemo('demo-basketball');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutCalendar(initialDate: DateTime(2028, 2, 29)),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('calendar-day-29')), findsOneWidget);
    expect(find.byKey(const Key('calendar-day-30')), findsNothing);
    await keyTap(tester, 'calendar-next');
    expect(find.text('2028년 3월'), findsOneWidget);
    await keyTap(tester, 'calendar-prev');
    await keyTap(tester, 'calendar-day-29');
    await keyTap(tester, 'calendar-add');
    await tester.enterText(find.byKey(const Key('event-title')), '학교 농구');
    await keyTap(tester, 'event-save');
    expect(app.members.profile!.events.single.title, '학교 농구');
    await tap(tester, find.text('예정'));
    expect(app.members.profile!.events.single.completed, isTrue);
    await tap(tester, find.byTooltip('일정 수정'));
    await tester.enterText(find.byKey(const Key('event-title')), '수정한 농구');
    await keyTap(tester, 'event-save');
    expect(app.members.profile!.events.single.title, '수정한 농구');
    await tap(tester, find.byTooltip('일정 삭제'));
    await tap(tester, find.text('삭제'));
    expect(app.members.profile!.events, isEmpty);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets(
    'AI retry does not duplicate a question; history reaches gateway',
    (tester) async {
      final g = FakeAi();
      final app = AppState(aiGateway: g);
      await app.members.initialize();
      await app.members.useDemo('demo-basketball');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: app,
          child: MaterialApp(
            home: Scaffold(body: AiChatScreen(gateway: g)),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('ai-input')), '농구 전술');
      await keyTap(tester, 'ai-send');
      expect(g.calls.length, 1);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('ai-send'))).onPressed,
        isNull,
      );
      g.pending[0].completeError(const AiFailure('연결 실패'));
      await tester.pumpAndSettle();
      await keyTap(tester, 'ai-retry');
      expect(g.calls.last.length, 1);
      g.pending[1].complete('패스 후 이동하세요');
      await tester.pumpAndSettle();
      expect(find.text('패스 후 이동하세요'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ai-input')), '다음 연습은?');
      await keyTap(tester, 'ai-send');
      expect(g.calls.last.length, 3);
      await tester.pumpWidget(const SizedBox());
      g.pending[2].complete('늦은 답변');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      app.dispose();
    },
  );
}
