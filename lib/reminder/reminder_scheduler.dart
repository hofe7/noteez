import 'dart:async';

DateTime _systemNow() => DateTime.now();

/// 스티커별 리마인더 타이머 관리(순수 스케줄링). 발화 시 onFire(id) 호출.
/// 예약 시각이 이미 지났으면 즉시 발화(catch-up — 앱이 꺼져 있던 동안의 건).
/// DB/창 의존 없음 → 단위 테스트 용이. now 주입으로 시간 제어 가능.
class ReminderScheduler {
  ReminderScheduler(this.onFire, {DateTime Function() now = _systemNow})
      : _now = now;

  final void Function(String id) onFire;
  final DateTime Function() _now;
  final Map<String, Timer> _timers = {};

  /// id 의 리마인더를 atMillis 로 (재)예약. 기존 예약은 취소.
  /// atMillis 가 null 이면 취소만. 과거/현재면 즉시 onFire(catch-up).
  void schedule(String id, int? atMillis) {
    _timers.remove(id)?.cancel();
    if (atMillis == null) return;
    final delay = atMillis - _now().millisecondsSinceEpoch;
    if (delay <= 0) {
      onFire(id);
      return;
    }
    _timers[id] = Timer(Duration(milliseconds: delay), () {
      _timers.remove(id);
      onFire(id);
    });
  }

  void cancel(String id) => _timers.remove(id)?.cancel();

  bool isScheduled(String id) => _timers.containsKey(id);

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
