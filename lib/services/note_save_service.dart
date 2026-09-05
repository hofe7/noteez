import '../models/sticky.dart';

/// Serializes commits and only publishes successfully persisted notes.
/// An update of a deleted note returns false and must not recreate it.
class NoteSaveService {
  NoteSaveService({
    required this.persist,
    required this.publish,
    required this.read,
  });
  final Sticky? Function(String id) read;
  final Future<bool> Function(Sticky note) persist;
  final void Function(Sticky note) publish;
  Future<void> _tail = Future.value();

  Future<void> save(Sticky note) => _enqueue(() => note);
  Future<void> update(String id, Sticky Function(Sticky) change) =>
      _enqueue(() {
        final current = read(id);
        return current == null ? null : change(current);
      });
  Future<void> flush() => _tail;

  /// An atomic multi-note operation shares the editor commit queue.
  Future<T> exclusive<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _enqueue(Sticky? Function() next) {
    final operation = _tail.then((_) async {
      final note = next();
      if (note != null && await persist(note)) publish(note);
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }
}
