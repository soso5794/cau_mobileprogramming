import 'package:flutter/foundation.dart';

enum NotificationTopic {
  team('팀·크루 소식', '가입한 크루의 공지와 새 소식'),
  participation('모집·참가', '신청 결과와 대기 순번'),
  schedule('운동 일정', '운동 시작 전 알림'),
  changes('날씨·장소 변경', '참가한 모임의 변경안과 재확인'),
  messages('댓글·메시지', '나와 관련된 대화'),
  recommendations('추천 모임', '관심 종목과 맞는 모임');

  const NotificationTopic(this.label, this.description);
  final String label;
  final String description;
}

/// 기기 권한과 분리된 사용자 선호. 이 과제에서는 메모리에만 저장한다.
@immutable
class NotificationPreferences {
  NotificationPreferences({
    this.enabled = true,
    Set<NotificationTopic>? topics,
    Set<int>? reminderMinutes,
    this.quietEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 8 * 60,
  }) : topics = Set.unmodifiable(
         topics ??
             {
               NotificationTopic.team,
               NotificationTopic.participation,
               NotificationTopic.schedule,
               NotificationTopic.changes,
               NotificationTopic.messages,
             },
       ),
       reminderMinutes = Set.unmodifiable(reminderMinutes ?? {1440, 60});

  final bool enabled;
  final Set<NotificationTopic> topics;
  final Set<int> reminderMinutes;
  final bool quietEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  NotificationPreferences copyWith({
    bool? enabled,
    Set<NotificationTopic>? topics,
    Set<int>? reminderMinutes,
    bool? quietEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    topics: topics ?? this.topics,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      enabled == other.enabled &&
      setEquals(topics, other.topics) &&
      setEquals(reminderMinutes, other.reminderMinutes) &&
      quietEnabled == other.quietEnabled &&
      quietStartMinutes == other.quietStartMinutes &&
      quietEndMinutes == other.quietEndMinutes;

  @override
  int get hashCode => Object.hash(
    enabled,
    Object.hashAllUnordered(topics),
    Object.hashAllUnordered(reminderMinutes),
    quietEnabled,
    quietStartMinutes,
    quietEndMinutes,
  );
}
