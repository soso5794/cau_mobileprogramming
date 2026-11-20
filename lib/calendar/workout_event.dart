import 'package:flutter/foundation.dart';

/// Device-local wall-clock schedule, independent of demo team data.
@immutable
class WorkoutEvent {
  const WorkoutEvent({
    required this.id,
    required this.title,
    required this.sport,
    required this.start,
    required this.minutes,
    this.place = '',
    this.notes = '',
    this.completed = false,
  });
  final String id, title, sport, place, notes;
  final DateTime start;
  final int minutes;
  final bool completed;
  DateTime get end => start.add(Duration(minutes: minutes));
  bool occursOn(DateTime date) =>
      start.year == date.year &&
      start.month == date.month &&
      start.day == date.day;
  bool overlaps(WorkoutEvent other) =>
      id != other.id && start.isBefore(other.end) && end.isAfter(other.start);
  WorkoutEvent withCompleted(bool value) => WorkoutEvent(
    id: id,
    title: title,
    sport: sport,
    start: start,
    minutes: minutes,
    place: place,
    notes: notes,
    completed: value,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'sport': sport,
    'start': start.toIso8601String(),
    'minutes': minutes,
    'place': place,
    'notes': notes,
    'completed': completed,
  };
  factory WorkoutEvent.fromJson(Map<String, dynamic> j) => WorkoutEvent(
    id: j['id'] as String,
    title: j['title'] as String,
    sport: j['sport'] as String,
    start: DateTime.parse(j['start'] as String),
    minutes: j['minutes'] as int,
    place: j['place'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    completed: j['completed'] as bool? ?? false,
  );
  String? validate() {
    if (title.trim().isEmpty || title.length > 60) {
      return '일정 제목은 1~60자로 입력해주세요.';
    }
    if (sport.trim().isEmpty) return '운동 종목을 선택해주세요.';
    if (minutes < 10 || minutes > 720) return '운동 시간은 10~720분으로 입력해주세요.';
    if (place.length > 100 || notes.length > 500) {
      return '장소는 100자, 메모는 500자 이내로 입력해주세요.';
    }
    if (start.year < 2000 || start.year > 2100) {
      return '2000~2100년 사이의 날짜를 선택해주세요.';
    }
    return null;
  }
}
