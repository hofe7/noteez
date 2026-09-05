import 'dart:async';

DateTime _systemNow() => DateTime.now();

/// Keeps failed deliveries scheduled and checks wall time after sleep.
/// Replacing/cancelling a reservation invalidates its in-flight retry.
class ReminderScheduler {
  ReminderScheduler(
    this.onFire, {
    DateTime Function() now = _systemNow,
    this.retryDelay = const Duration(seconds: 30),
    this.checkInterval = const Duration(seconds: 30),
    this.onError,
  }) : _now = now;

  final FutureOr<void> Function(String id) onFire;
  final DateTime Function() _now;
  final Duration retryDelay;
  final Duration checkInterval;
  final void Function(Object, StackTrace)? onError;
  final Map<String, _Reservation> _pending = {};
  Timer? _clockCheck;
  bool _disposed = false;

  void schedule(String id, int? atMillis) {
    cancel(id);
    if (atMillis == null || _disposed) return;
    final entry = _Reservation(atMillis);
    _pending[id] = entry;
    _clockCheck ??= Timer.periodic(checkInterval, (_) => checkDue());
    _arm(id, entry);
  }

  void _arm(String id, _Reservation entry) {
    final delay = entry.at - _now().millisecondsSinceEpoch;
    if (delay <= 0) {
      unawaited(_fire(id, entry));
    } else {
      entry.timer = Timer(Duration(milliseconds: delay), () {
        unawaited(_fire(id, entry));
      });
    }
  }

  Future<void> _fire(String id, _Reservation entry) async {
    if (_disposed || _pending[id] != entry || entry.firing) return;
    entry.timer?.cancel();
    entry.firing = true;
    try {
      // Future.sync also captures synchronous callback failures.
      await Future<void>.sync(() => onFire(id));
      if (_pending[id] == entry) cancel(id);
    } catch (error, stack) {
      if (!_disposed && _pending[id] == entry) {
        entry.firing = false;
        entry.at = _now().millisecondsSinceEpoch + retryDelay.inMilliseconds;
        _arm(id, entry);
      }
      onError?.call(error, stack);
    }
  }

  /// Explicitly callable on resume; periodic checks also cover OS sleep.
  void checkDue() {
    for (final item in _pending.entries.toList()) {
      if (item.value.at <= _now().millisecondsSinceEpoch) {
        unawaited(_fire(item.key, item.value));
      }
    }
  }

  void cancel(String id) {
    _pending.remove(id)?.timer?.cancel();
    if (_pending.isEmpty) {
      _clockCheck?.cancel();
      _clockCheck = null;
    }
  }

  bool isScheduled(String id) => _pending.containsKey(id);

  void dispose() {
    _disposed = true;
    for (final entry in _pending.values) {
      entry.timer?.cancel();
    }
    _pending.clear();
    _clockCheck?.cancel();
    _clockCheck = null;
  }
}

class _Reservation {
  _Reservation(this.at);
  int at;
  bool firing = false;
  Timer? timer;
}
