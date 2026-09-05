import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/markdown/markdown_codec.dart';
import 'package:noteez/markdown/markdown_portability.dart';
import 'package:noteez/services/markdown_import_service.dart';

void main() {
  late AppDatabase db;
  late MarkdownImportService importer;
  ImportedMarkdownNote note(String id, {String? text, String? externalId}) =>
      ImportedMarkdownNote(
        sourcePath: '$id.md',
        sourceKey: id,
        sourceHash: text ?? id,
        title: id,
        blocks: [textBlock(text ?? id)],
        references: [],
        metadata: NoteMarkdownMetadata(
          noteezId: externalId,
          noteezGroupId: 'project',
          noteezGroupName: '업무',
        ),
      );
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = MarkdownImportService(
      db,
      documentHash: (n) => jsonEncode(n.blocks.map((b) => b.text).toList()),
    );
  });
  tearDown(() => db.close());
  MarkdownImportBatch batch() => MarkdownImportBatch(
    [note('a'), note('b')],
    [const ImportedMarkdownLink('a.md', 'b.md')],
    [],
  );

  test(
    'late group failure rolls back notes, origins and links; retry imports once',
    () async {
      await db.allActive();
      await db.customStatement(
        "CREATE TRIGGER fail_group BEFORE INSERT ON group_members BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(importer.store(batch()), throwsA(anything));
      expect(await db.allActive(), isEmpty);
      expect(await db.allActiveLinks(), isEmpty);
      expect(await db.allActiveGroups(), isEmpty);
      expect(await db.importOrigin('a'), isNull);
      await db.customStatement('DROP TRIGGER fail_group');
      final result = await importer.store(batch());
      expect(result.imported, 2);
      expect(result.linked, 1);
      expect(await db.allGroupMembers(), hasLength(2));
      final retry = await importer.store(batch());
      expect(retry.skipped, 2);
      expect(await db.allActive(), hasLength(2));
    },
  );
  test(
    'concurrent duplicate batches read committed origins and do not duplicate notes',
    () async {
      final results = await Future.wait([
        importer.store(batch()),
        importer.store(batch()),
      ]);
      expect(results.map((r) => r.imported).reduce((a, b) => a + b), 2);
      expect(await db.allActive(), hasLength(2));
      expect(await db.allActiveLinks(), hasLength(1));
    },
  );
  test('a changed open memo is preserved separately', () async {
    await importer.store(batch());
    final existing = (await db.allActive()).firstWhere((n) => n.preview == 'a');
    await db.updateExisting(existing.copyWith(open: true));
    final result = await importer.store(
      MarkdownImportBatch([note('a', text: 'changed source')], [], []),
    );
    expect(result.conflicted, 1);
    expect(
      (await db.allActive()).map((n) => n.preview),
      containsAll(['a', 'changed source']),
    );
  });
  test(
    'external ID matching a trashed memo cannot overwrite its saved content',
    () async {
      final old = makeSticky(x: 0, y: 0, blocks: [textBlock('trash original')]);
      await db.upsert(old);
      await db.trashNote(old.id);
      await importer.store(
        MarkdownImportBatch([note('a', externalId: old.id)], [], []),
      );
      expect((await db.allActive()).single.id, isNot(old.id));
      expect(
        (await db.allTrashed()).single.blocksJson,
        contains('trash original'),
      );
    },
  );
}
