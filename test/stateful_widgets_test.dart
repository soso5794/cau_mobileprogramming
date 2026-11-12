import 'package:exercise_assist/models/app_state.dart';
import 'package:exercise_assist/models/notification_preferences.dart';
import 'package:exercise_assist/screens/notification_settings_screen.dart';
import 'package:exercise_assist/screens/sport_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'routing_test.dart' show openApp, login;

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('saved settings are immutable and isolated between accounts', () {
    final app = AppState()..login('alice', 'demo');
    addTearDown(app.dispose);
    final topics = {NotificationTopic.team};
    final value = NotificationPreferences(topics: topics, enabled: false);
    expect(app.saveNotificationPreferences('alice', value), isTrue);
    topics.clear();
    expect(app.notificationPreferences.topics, {NotificationTopic.team});
    expect(() => value.topics.clear(), throwsUnsupportedError);
    app.logout();
    app.login('bob', 'demo');
    expect(app.notificationPreferences.enabled, isTrue);
    expect(app.saveNotificationPreferences('alice', value), isFalse);
    app.logout();
    app.login('alice', 'demo');
    expect(app.notificationPreferences, value);
  });

  testWidgets('draft stays local; save survives leaving and reopening', (
    tester,
  ) async {
    final app = AppState()..login('demo', 'demo');
    await openApp(tester, app, location: '/sports');
    await tester.tap(find.byTooltip('알림 설정'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-notifications')))
          .onPressed,
      isNull,
    );
    await tapKey(tester, 'topic-team');
    expect(
      app.notificationPreferences.topics,
      contains(NotificationTopic.team),
    );
    await tapKey(tester, 'save-notifications');
    expect(
      app.notificationPreferences.topics,
      isNot(contains(NotificationTopic.team)),
    );
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('알림 설정'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('topic-team'))).value,
      isFalse,
    );
  });

  testWidgets('system back asks to discard; continuing keeps draft', (
    tester,
  ) async {
    final app = AppState()..login('demo', 'demo');
    final router = await openApp(tester, app, location: '/sports');
    await tester.tap(find.byTooltip('알림 설정'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'notifications-enabled');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('변경사항을 버릴까요?'), findsOneWidget);
    await tester.tap(find.text('계속 수정'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('notifications-enabled')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('변경 버리기'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sports');
    expect(app.notificationPreferences.enabled, isTrue);
  });

  testWidgets('master toggle preserves choices and reminders save', (
    tester,
  ) async {
    final app = AppState()..login('demo', 'demo');
    await openApp(tester, app, location: '/settings/notifications');
    await tapKey(tester, 'notifications-enabled');
    final team = tester.widget<SwitchListTile>(
      find.byKey(const Key('topic-team')),
    );
    expect(team.onChanged, isNull);
    expect(team.value, isTrue);
    await tapKey(tester, 'notifications-enabled');
    await tapKey(tester, 'reminder-30');
    await tapKey(tester, 'save-notifications');
    expect(app.notificationPreferences.reminderMinutes, {1440, 60, 30});
    expect(
      app.notificationPreferences.topics,
      contains(NotificationTopic.team),
    );
  });

  testWidgets('notification deep link requires login and can return home', (
    tester,
  ) async {
    final router = await openApp(
      tester,
      AppState(),
      location: '/settings/notifications',
    );
    await login(tester);
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sports');
  });

  testWidgets(
    'time picker cancellation keeps the draft and saving quiet mode works',
    (tester) async {
      final app = AppState()..login('demo', 'demo');
      await openApp(tester, app, location: '/settings/notifications');
      await tapKey(tester, 'quiet-enabled');
      await tapKey(tester, 'quiet-start');
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('시작 22:00'), findsOneWidget);
      await tapKey(tester, 'save-notifications');
      expect(app.notificationPreferences.quietEnabled, isTrue);
      expect(app.notificationPreferences.quietStartMinutes, 1320);
    },
  );

  testWidgets('sport search keeps hidden selections; cancel and save differ', (
    tester,
  ) async {
    final app = AppState()..login('demo', 'demo');
    app.setSelectedSports(['농구']);
    await openApp(tester, app, location: '/sports');
    await tester.tap(find.text('선호 운동 추가 / 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sport-search')), '자전거');
    await tester.pumpAndSettle();
    await tapKey(tester, 'pick-자전거');
    expect(app.selectedSports, ['농구']);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(app.selectedSports, ['농구']);
    await tester.tap(find.text('선호 운동 추가 / 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sport-search')), '자전거');
    await tester.pumpAndSettle();
    await tapKey(tester, 'pick-자전거');
    await tapKey(tester, 'save-sports');
    expect(app.selectedSports, ['농구', '자전거']);
    expect(find.byType(SportPickerSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker fits a small screen with keyboard and enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            viewInsets: EdgeInsets.only(bottom: 280),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: SportPickerSheet(initialSelection: ['농구']),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
