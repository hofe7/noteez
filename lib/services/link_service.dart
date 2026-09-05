import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/link_change.dart';

/// Serializes graph writes. Receipts compare durable row identities, including
/// tombstones, so remove/re-add and trash/restore cannot pass as unchanged.
class LinkService {
  LinkService(this.db, {required this.publish});
  final AppDatabase db;
  final void Function(String a, String b, bool linked) publish;
  final _receipts =
      <String, ({String a, String b, bool before, String after})>{};
  Future<void> _tail = Future.value();
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> flush() => _tail;

  Future<List<LinkRow>> _rows(String a, String b) =>
      (db.select(db.links)
            ..where(
              (t) =>
                  (t.aId.equals(a) & t.bId.equals(b)) |
                  (t.aId.equals(b) & t.bId.equals(a)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
  String _signature(List<LinkRow> rows) => jsonEncode([
    for (final row in rows) [row.id, row.deletedAt],
  ]);
  Future<void> _checkNotes(String a, String b) async {
    if (a == b) throw const LinkChangeConflict();
    final rows = await (db.select(
      db.stickies,
    )..where((t) => t.id.isIn([a, b]) & t.deletedAt.isNull())).get();
    if (rows.length != 2) throw const LinkChangeConflict();
  }

  Future<void> _write(String a, String b, bool linked) async {
    if (linked) {
      await db.insertLink(
        const Uuid().v4(),
        a,
        b,
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await db.softDeleteLinkBetween(a, b);
    }
  }

  Future<LinkChange> set(String a, String b, bool linked) => _enqueue(() async {
    final result = await db.transaction(() async {
      await _checkNotes(a, b);
      final rows = await _rows(a, b);
      final before = rows.any((r) => r.deletedAt == null);
      if (before == linked) return null;
      await _write(a, b, linked);
      return (a: a, b: b, before: before, after: _signature(await _rows(a, b)));
    });
    publish(a, b, linked);
    if (result == null) return const LinkChange(null);
    final token = const Uuid().v4();
    _receipts[token] = result;
    // Undo is session-local and bounded.
    if (_receipts.length > 100) _receipts.remove(_receipts.keys.first);
    return LinkChange(token);
  });

  Future<void> undo(String token) => _enqueue(() async {
    final receipt = _receipts[token];
    if (receipt == null) throw const LinkChangeConflict();
    await db.transaction(() async {
      await _checkNotes(receipt.a, receipt.b);
      if (_signature(await _rows(receipt.a, receipt.b)) != receipt.after) {
        throw const LinkChangeConflict();
      }
      await _write(receipt.a, receipt.b, receipt.before);
    });
    _receipts.remove(token);
    publish(receipt.a, receipt.b, receipt.before);
  });
}
