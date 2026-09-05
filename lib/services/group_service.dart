import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/group_change.dart';

/// Owns group edits and bounded, session-only undo receipts. Clients receive an
/// opaque token; they cannot supply stale "previous state" as an undo command.
class GroupService {
  GroupService(this.db);
  final AppDatabase db;
  final _undo = <String, Future<void> Function()>{};
  final _uuid = const Uuid();

  GroupChange _remember(Future<void> Function() undo, {String? groupId}) {
    final token = _uuid.v4();
    _undo[token] = undo;
    while (_undo.length > 100) {
      _undo.remove(_undo.keys.first);
    }
    return GroupChange(undoToken: token, groupId: groupId);
  }

  Future<Map<String, String?>> _previous(Iterable<String> ids) async {
    final live = (await db.allActive()).map((n) => n.id).toSet();
    final members = {
      for (final m in await db.allGroupMembers()) m.stickyId: m.groupId,
    };
    if (ids.any((id) => !live.contains(id))) throw const GroupChangeConflict();
    return {for (final id in ids) id: members[id]};
  }

  Future<NoteGroupRow> _group(String id) async =>
      (await db.allActiveGroups()).firstWhere(
        (g) => g.id == id,
        orElse: () => throw const GroupChangeConflict(),
      );

  GroupChange _membershipUndo(
    Map<String, String?> previous, {
    String? createdId,
    String? groupId,
  }) {
    final expected = {
      for (final id in previous.keys) id: db.membershipRevision(id),
    };
    final createdRevision = createdId == null
        ? null
        : db.groupRevision(createdId);
    return _remember(
      () => db.restoreNoteMemberships(
        previous,
        expectedRevisions: expected,
        deleteGroupId: createdId,
        expectedCreatedGroupRevision: createdRevision,
      ),
      groupId: groupId ?? createdId,
    );
  }

  String _name(String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty || name.length > 80) {
      throw ArgumentError('묶음 이름은 1~80자여야 합니다.');
    }
    return name;
  }

  Future<({List<NoteGroupRow> groups, List<GroupMemberRow> members})>
  snapshot() => db.transaction(
    () async => (
      groups: await db.allActiveGroups(),
      members: await db.allGroupMembers(),
    ),
  );

  /// Import metadata may contain old IDs or long names. Imported groups do not
  /// create interactive undo receipts; their membership changes still invalidate
  /// any affected receipts from this session.
  Future<String> importGroup(
    String name, {
    String? requestedId,
    bool collapsed = false,
    int? position,
  }) => db.groupTransaction(() async {
    final groups = await db.allActiveGroups();
    var cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.isEmpty) cleanName = '새 묶음';
    if (cleanName.length > 80) {
      cleanName = cleanName.substring(0, 80).trimRight();
    }
    final id = requestedId?.trim().isNotEmpty == true
        ? requestedId!.trim()
        : _uuid.v4();
    await db.upsertNoteGroup(
      id: id,
      name: cleanName,
      position:
          position ??
          groups.fold<int>(
                -1,
                (max, g) => g.position > max ? g.position : max,
              ) +
              1,
      collapsed: collapsed,
    );
    return id;
  });

  Future<GroupChange> create(String name, List<String> ids) =>
      db.groupTransaction(() async {
        final previous = await _previous(ids);
        final groups = await db.allActiveGroups();
        final position =
            groups.fold<int>(
              -1,
              (max, g) => g.position > max ? g.position : max,
            ) +
            1;
        final id = _uuid.v4();
        await db.upsertNoteGroup(id: id, name: _name(name), position: position);
        await db.assignNotesToGroup(id, ids);
        return _membershipUndo(previous, createdId: id);
      });

  Future<GroupChange> move(String groupId, List<String> ids) =>
      db.groupTransaction(() async {
        await _group(groupId);
        final previous = await _previous(ids);
        await db.assignNotesToGroup(groupId, ids);
        return _membershipUndo(previous, groupId: groupId);
      });

  Future<GroupChange> remove(List<String> ids) => db.groupTransaction(() async {
    final previous = await _previous(ids);
    await db.removeNotesFromGroup(ids);
    return _membershipUndo(previous);
  });

  Future<GroupChange> rename(String id, String name) => db.groupTransaction(
    () async {
      final before = await _group(id);
      await db.renameNoteGroup(id, _name(name));
      final expected = db.groupRevision(id);
      return _remember(() async {
        if (db.groupRevision(id) != expected) throw const GroupChangeConflict();
        await _group(id);
        await db.renameNoteGroup(id, before.name);
      }, groupId: id);
    },
  );

  Future<GroupChange> delete(String id) => db.groupTransaction(() async {
    final before = await _group(id);
    final previous = {
      for (final m in await db.allGroupMembers())
        if (m.groupId == id) m.stickyId: id,
    };
    await db.softDeleteNoteGroup(id);
    final expected = {
      for (final note in previous.keys) note: db.membershipRevision(note),
    };
    final groupRevision = db.groupRevision(id);
    return _remember(() async {
      if (db.groupRevision(id) != groupRevision ||
          previous.keys.any((n) => db.membershipRevision(n) != expected[n])) {
        throw const GroupChangeConflict();
      }
      await db.upsertNoteGroup(
        id: id,
        name: before.name,
        position: before.position,
        collapsed: before.collapsed,
        createdAt: before.createdAt,
      );
      await db.restoreNoteMemberships(previous, expectedRevisions: expected);
    }, groupId: id);
  });

  Future<void> undo(String token) async {
    await db.groupTransaction(() async {
      final action = _undo[token];
      if (action == null) throw const GroupChangeConflict();
      await action();
    });
    _undo.remove(token);
  }
}
