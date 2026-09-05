import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/models/group_change.dart';
import 'package:noteez/services/group_service.dart';

void main() {
  late AppDatabase db;
  late GroupService groups;
  late List<String> ids;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    groups = GroupService(db);
    ids = [];
    for (var i = 0; i < 3; i++) {
      final note = makeSticky(x: 0, y: 0, blocks: [textBlock('note $i')]);
      ids.add(note.id);
      await db.upsert(note);
    }
    for (final id in ['a', 'b', 'c']) {
      await db.upsertNoteGroup(id: id, name: id, position: 0);
    }
    await db.assignNotesToGroup('a', ids.take(2));
  });
  tearDown(() => db.close());
  Future<Map<String, String>> membership() async => {
    for (final m in await db.allGroupMembers()) m.stickyId: m.groupId,
  };
  test('later moves including ABA reject stale undo atomically', () async {
    final move = await groups.move('b', ids.take(2).toList());
    await groups.move('c', [ids[0]]);
    await expectLater(
      groups.undo(move.undoToken),
      throwsA(isA<GroupChangeConflict>()),
    );
    expect(await membership(), {ids[0]: 'c', ids[1]: 'b'});
    await groups.move('b', [ids[0]]);
    await expectLater(
      groups.undo(move.undoToken),
      throwsA(isA<GroupChangeConflict>()),
    );
    expect(await membership(), {ids[0]: 'b', ids[1]: 'b'});
  });
  test('ungrouped ABA is a change too', () async {
    final remove = await groups.remove([ids[0]]);
    await groups.move('c', [ids[0]]);
    await groups.remove([ids[0]]);
    await expectLater(
      groups.undo(remove.undoToken),
      throwsA(isA<GroupChangeConflict>()),
    );
    expect((await membership()).containsKey(ids[0]), isFalse);
  });
  test(
    'undo creation restores old memberships and preserves other members',
    () async {
      final created = await groups.create('new', [ids[0], ids[2]]);
      await groups.move(created.groupId!, [ids[1]]);
      await groups.undo(created.undoToken);
      expect(await membership(), {ids[0]: 'a', ids[1]: created.groupId!});
      expect(
        (await db.allActiveGroups()).any((g) => g.id == created.groupId),
        isTrue,
      );
      await expectLater(
        groups.undo(created.undoToken),
        throwsA(isA<GroupChangeConflict>()),
      );
    },
  );
  test('rename detects later renames even when the name returns', () async {
    final rename = await groups.rename('a', 'changed');
    await groups.rename('a', 'elsewhere');
    await groups.rename('a', 'changed');
    await expectLater(
      groups.undo(rename.undoToken),
      throwsA(isA<GroupChangeConflict>()),
    );
    expect(
      (await db.allActiveGroups()).firstWhere((g) => g.id == 'a').name,
      'changed',
    );
  });
  test('undo deletion cannot reclaim members moved elsewhere', () async {
    final deleted = await groups.delete('a');
    await groups.move('c', [ids[0]]);
    await expectLater(
      groups.undo(deleted.undoToken),
      throwsA(isA<GroupChangeConflict>()),
    );
    expect((await db.allActiveGroups()).any((g) => g.id == 'a'), isFalse);
    expect(await membership(), {ids[0]: 'c'});
  });
  test('normal delete undo restores the group and its members', () async {
    final deleted = await groups.delete('a');
    await groups.undo(deleted.undoToken);
    expect(await membership(), {ids[0]: 'a', ids[1]: 'a'});
    expect((await db.allActiveGroups()).any((g) => g.id == 'a'), isTrue);
  });
  test('failed creation rolls back both group and memberships', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_group_member BEFORE INSERT ON group_members BEGIN SELECT RAISE(ABORT, 'write failed'); END",
    );
    await expectLater(groups.create('failed', [ids[0]]), throwsA(anything));
    expect(
      (await db.allActiveGroups()).map((g) => g.name),
      isNot(contains('failed')),
    );
    expect((await membership())[ids[0]], 'a');
  });
  test('failed undo rolls back revisions too, allowing a safe retry', () async {
    final move = await groups.move('b', ids.take(2).toList());
    await db.customStatement(
      "CREATE TRIGGER fail_undo BEFORE INSERT ON group_members WHEN NEW.group_id = 'a' BEGIN SELECT RAISE(ABORT, 'write failed'); END",
    );
    await expectLater(groups.undo(move.undoToken), throwsA(anything));
    expect(await membership(), {ids[0]: 'b', ids[1]: 'b'});
    await db.customStatement('DROP TRIGGER fail_undo');
    await groups.undo(move.undoToken);
    expect(await membership(), {ids[0]: 'a', ids[1]: 'a'});
  });
  test('overlapping commands capture distinct committed revisions', () async {
    final changes = await Future.wait([
      groups.move('b', [ids[0]]),
      groups.move('c', [ids[0]]),
    ]);
    expect((await membership())[ids[0]], 'c');
    await expectLater(
      groups.undo(changes.first.undoToken),
      throwsA(isA<GroupChangeConflict>()),
    );
    await groups.undo(changes.last.undoToken);
    expect((await membership())[ids[0]], 'b');
  });
}
