import 'dart:async';

/// Coalesces edits and serializes writes. Closing a window must await [flush].
/// A failed write stays pending so a later flush can retry without losing edits.
class PendingSave<T extends Object> {
  PendingSave({
    required this.write,
    required this.onError,
    this.delay = const Duration(milliseconds: 300),
  });

  final Future<void> Function(T value) write;
  final void Function(Object error) onError;
  final Duration delay;
  Timer? _timer;
  T? _pending;
  Future<void>? _running;
  bool _disposed = false;

  void schedule(T value) {
    if (_disposed) return;
    _pending = value;
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(flush().catchError((Object error) => onError(error)));
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    final running = _running;
    if (running != null) {
      await running;
      return flush();
    }
    final value = _pending;
    if (value == null || _disposed) return;
    _pending = null;
    final operation = Future<void>.sync(() => write(value));
    _running = operation;
    try {
      await operation;
    } catch (_) {
      _pending ??= value;
      rethrow;
    } finally {
      _running = null;
    }
    // Edits made while the write was in flight must also reach storage.
    if (_pending != null) await flush();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending = null;
  }
}
