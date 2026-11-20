import 'package:flutter/foundation.dart';

import 'member_models.dart';
import 'member_repository.dart';
import '../calendar/workout_event.dart';

class MemberController extends ChangeNotifier {
  MemberController(this.repository);
  final MemberRepository repository;
  MemberProfile? get profile => repository.current;
  bool ready = false, busy = false, _disposed = false;
  String? error, errorField;
  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    errorField = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on MemberFailure catch (e) {
      error = e.message;
      errorField = e.field;
      return false;
    } catch (_) {
      error = '기기 저장소를 읽거나 저장하지 못했어요. 다시 시도해주세요.';
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> initialize() => _run(() async {
    await repository.restore();
    ready = true;
  });
  Future<bool> signUp(
    String name,
    String email,
    String password,
    bool agreed,
  ) => _run(() => repository.signUp(name, email, password, agreed));
  Future<bool> login(String email, String password, bool remember) =>
      _run(() => repository.login(email, password, remember));
  Future<bool> useDemo(String id) => _run(() => repository.useDemo(id));
  Future<bool> save(MemberProfile p) => _run(() => repository.save(p));
  Future<bool> logout() => _run(repository.logout);
  Future<bool> toggleFavorite(String sport) async {
    final p = profile;
    if (p == null) return false;
    final next = {...p.favorites};
    if (!next.add(sport)) next.remove(sport);
    return save(p.copyWith(favorites: next));
  }

  Future<bool> cancelApplication(String id) async {
    final p = profile;
    if (p == null || !p.isDemo) return false;
    return save(
      p.copyWith(cancelledApplications: {...p.cancelledApplications, id}),
    );
  }

  Future<bool> saveEvent(WorkoutEvent event, {required String ownerId}) =>
      _run(() async {
        final p = profile;
        if (p == null || p.id != ownerId) {
          throw const MemberFailure('계정이 바뀌었어요. 캘린더를 다시 열어주세요.');
        }
        final problem = event.validate();
        if (problem != null) throw MemberFailure(problem);
        final events = [...p.events.where((e) => e.id != event.id), event]
          ..sort((a, b) => a.start.compareTo(b.start));
        await repository.save(p.copyWith(events: events));
      });
  Future<bool> deleteEvent(String id, {required String ownerId}) =>
      _run(() async {
        final p = profile;
        if (p == null || p.id != ownerId) {
          throw const MemberFailure('계정이 바뀌었어요. 캘린더를 다시 열어주세요.');
        }
        await repository.save(
          p.copyWith(events: p.events.where((e) => e.id != id).toList()),
        );
      });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
