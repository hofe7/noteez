import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
    'welcome initialization is persistent after all notes are deleted',
    () async {
      await db.initializeWelcome();
      final note = (await db.allActive()).single;
      await db.softDelete(note.id);
      await db.initializeWelcome();
      expect(await db.allActive(), isEmpty);
      // Even a future permanent cleanup must not reset first-launch state.
      await db.customStatement('DELETE FROM stickies');
      await db.initializeWelcome();
      expect(await db.allActive(), isEmpty);
    },
  );

  test(
    'window changes preserve content time through database and IPC',
    () async {
      final original = makeSticky(x: 0, y: 0);
      final moved = original.copyWith(x: 200, updatedAt: DateTime(2030));
      await db.upsert(moved);
      final restored = (await db.allActive()).single;
      expect(restored.updatedAt, DateTime(2030));
      expect(
        restored.contentUpdatedAt.millisecondsSinceEpoch,
        original.contentUpdatedAt.millisecondsSinceEpoch,
      );
      expect(
        Sticky.fromJson(restored.toJson()).contentUpdatedAt,
        DateTime.fromMillisecondsSinceEpoch(
          original.contentUpdatedAt.millisecondsSinceEpoch,
        ),
      );
      final edited = moved.copyWith(
        blocks: [textBlock('edited')],
        updatedAt: DateTime(2031),
      );
      expect(edited.contentUpdatedAt, DateTime(2031));
    },
  );

  test(
    'group rejection survives text changes and can be reset independently',
    () async {
      await db.dismissGroupSuggestion('note', 'group-a');
      await db.dismissGroupSuggestion('note', 'group-b');
      await db.dismissGroupSuggestion('note', 'group-a');
      await db.upsert(makeSticky(x: 0, y: 0));
      expect(await db.allGroupSuggestionDismissals(), hasLength(2));
      await db.resetGroupSuggestions('group-a');
      expect(
        (await db.allGroupSuggestionDismissals()).single.groupId,
        'group-b',
      );
    },
  );

  test('softDeleteLinkBetween removes either edge orientation', () async {
    await db.insertLink('first', 'a', 'b', 1);
    await db.insertLink('second', 'b', 'a', 2);

    await db.softDeleteLinkBetween('a', 'b');

    expect(await db.allActiveLinks(), isEmpty);
  });

  test('sticky window size is persisted', () async {
    final sticky = makeSticky(x: 10, y: 20).copyWith(width: 430, height: 370);

    await db.upsert(sticky);
    final restored = (await db.allActive()).single;

    expect(restored.width, 430);
    expect(restored.height, 370);
  });

  test('schema 10 notes migrate to the comfortable default size', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp(
      'noteez-size-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/noteez.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE stickies (
        id TEXT NOT NULL PRIMARY KEY,
        color_index INTEGER NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        collapsed INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0,
        open INTEGER NOT NULL DEFAULT 1,
        remind_at INTEGER,
        blocks_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    legacy.execute('''
      INSERT INTO stickies (
        id, color_index, x, y, blocks_json, created_at, updated_at
      ) VALUES ('legacy', 0, 10, 20, '[{"type":"text","id":"b","text":"old"}]', 1, 1)
    ''');
    legacy.execute('PRAGMA user_version = 10');
    legacy.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    final restored = (await db.allActive()).single;

    expect(restored.width, kDefaultStickyWidth);
    expect(restored.height, kDefaultStickyHeight);
    expect(restored.contentUpdatedAt, restored.updatedAt);
    await db.softDelete('legacy');
    await db.initializeWelcome();
    expect(await db.allActive(), isEmpty);
  });

  test('embedding cache is isolated by selected model', () async {
    await db.upsertEmbedding('note', 'e5-small', 'hash', '[1,2,3]');

    expect(await db.allEmbeddingsForModel('e5-small'), hasLength(1));
    expect(await db.allEmbeddingsForModel('e5-base'), isEmpty);

    await db.upsertEmbedding('note', 'e5-base', 'hash', '[4,5,6]');
    expect(await db.allEmbeddingsForModel('e5-small'), isEmpty);
    expect((await db.allEmbeddingsForModel('e5-base')).single.vec, '[4,5,6]');

    await db.deleteAllEmbeddings();
    expect(await db.allEmbeddingsForModel('e5-base'), isEmpty);
  });

  test(
    'suggestion dismissal is persisted, updated, and deleted per note',
    () async {
      await db.upsertSuggestionDismissal(
        aId: 'a',
        bId: 'b',
        aHash: 'old-a',
        bHash: 'old-b',
      );
      await db.upsertSuggestionDismissal(
        aId: 'a',
        bId: 'b',
        aHash: 'new-a',
        bHash: 'new-b',
      );

      final rows = await db.allSuggestionDismissals();
      expect(rows, hasLength(1));
      expect(rows.single.aHash, 'new-a');
      expect(rows.single.bHash, 'new-b');

      await db.deleteSuggestionDismissalsFor('a');
      expect(await db.allSuggestionDismissals(), isEmpty);
    },
  );

  test('import origin is updated and removed with its note', () async {
    await db.upsertImportOrigin(
      sourceKey: 'file:/vault/a.md',
      stickyId: 'a',
      sourceHash: 'source-1',
      stickyHash: 'sticky-1',
    );
    await db.upsertImportOrigin(
      sourceKey: 'file:/vault/a.md',
      stickyId: 'a',
      sourceHash: 'source-2',
      stickyHash: 'sticky-2',
    );

    final origin = await db.importOrigin('file:/vault/a.md');
    expect(origin?.sourceHash, 'source-2');
    expect(origin?.stickyHash, 'sticky-2');

    await db.deleteImportOriginsFor('a');
    expect(await db.importOrigin('file:/vault/a.md'), isNull);
  });

  test(
    'upsert restores a previously soft-deleted Markdown round-trip ID',
    () async {
      final now = DateTime(2026, 8, 27);
      final sticky = Sticky(
        id: 'restored-id',
        blocks: [const TextBlock(id: 'block', text: 'Restored')],
        colorIndex: 0,
        x: 0,
        y: 0,
        createdAt: now,
        updatedAt: now,
      );
      await db.upsert(sticky);
      await db.softDelete(sticky.id);
      expect(await db.allActive(), isEmpty);

      await db.upsert(sticky);

      expect((await db.allActive()).single.id, sticky.id);
    },
  );

  test(
    'manual group owns a note once and deleting it keeps the note',
    () async {
      final now = DateTime(2026, 9, 2);
      final sticky = Sticky(
        id: 'note',
        blocks: [const TextBlock(id: 'block', text: 'Keep me')],
        colorIndex: 0,
        x: 0,
        y: 0,
        createdAt: now,
        updatedAt: now,
      );
      await db.upsert(sticky);
      await db.upsertNoteGroup(id: 'a', name: '첫 묶음', position: 0);
      await db.upsertNoteGroup(id: 'b', name: '둘째 묶음', position: 1);

      await db.assignNotesToGroup('a', ['note']);
      await db.assignNotesToGroup('b', ['note']);

      final membership = (await db.allGroupMembers()).single;
      expect(membership.groupId, 'b');

      await db.renameNoteGroup('b', '새 이름');
      await db.setNoteGroupCollapsed('b', true);
      final group = (await db.allActiveGroups()).last;
      expect(group.name, '새 이름');
      expect(group.collapsed, isTrue);

      await db.softDeleteNoteGroup('b');
      expect(await db.allGroupMembers(), isEmpty);
      expect((await db.allActive()).single.id, 'note');
    },
  );
  test(
    'bulk organization undo restores membership and preserves later additions',
    () async {
      final notes = [
        for (var i = 0; i < 3; i++)
          makeSticky(x: 0, y: 0, blocks: [textBlock('note $i')]),
      ];
      for (final note in notes) {
        await db.upsert(note);
      }
      await db.upsertNoteGroup(id: 'old', name: '기존', position: 0);
      await db.upsertNoteGroup(id: 'created', name: '새 묶음', position: 1);
      await db.assignNotesToGroup('created', notes.map((n) => n.id));
      await db.restoreNoteMemberships(
        {notes[0].id: 'old', notes[1].id: null},
        deleteGroupId: 'created',
        expectedRevisions: {
          for (final n in notes.take(2)) n.id: db.membershipRevision(n.id),
        },
      );
      final members = {
        for (final m in await db.allGroupMembers()) m.stickyId: m.groupId,
      };
      expect(members, {notes[0].id: 'old', notes[2].id: 'created'});
      expect(
        (await db.allActiveGroups()).map((g) => g.id),
        contains('created'),
      );
      await db.restoreNoteMemberships(
        {notes[2].id: null},
        deleteGroupId: 'created',
        expectedRevisions: {notes[2].id: db.membershipRevision(notes[2].id)},
      );
      expect(
        (await db.allActiveGroups()).map((g) => g.id),
        isNot(contains('created')),
      );
      expect(await db.allActive(), hasLength(3));
    },
  );

  test(
    'undo rejects deleted destinations and rolls back a failed multi-note restore',
    () async {
      final a = makeSticky(x: 0, y: 0, blocks: [textBlock('a')]);
      final b = makeSticky(x: 0, y: 0, blocks: [textBlock('b')]);
      await db.upsert(a);
      await db.upsert(b);
      await db.upsertNoteGroup(id: 'current', name: '현재', position: 0);
      await db.upsertNoteGroup(id: 'old', name: '이전', position: 1);
      await db.assignNotesToGroup('current', [a.id, b.id]);
      await expectLater(
        db.restoreNoteMemberships(
          {a.id: null, b.id: 'missing'},
          expectedRevisions: {
            a.id: db.membershipRevision(a.id),
            b.id: db.membershipRevision(b.id),
          },
        ),
        throwsStateError,
      );
      expect(
        (await db.allGroupMembers()).every((m) => m.groupId == 'current'),
        isTrue,
      );
      await db.customStatement(
        "CREATE TRIGGER reject_restore BEFORE INSERT ON group_members WHEN NEW.group_id = 'old' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        db.restoreNoteMemberships(
          {a.id: null, b.id: 'old'},
          expectedRevisions: {
            a.id: db.membershipRevision(a.id),
            b.id: db.membershipRevision(b.id),
          },
        ),
        throwsA(anything),
      );
      final members = await db.allGroupMembers();
      expect(members, hasLength(2));
      expect(members.every((m) => m.groupId == 'current'), isTrue);
    },
  );
}
