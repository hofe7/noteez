import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('softDeleteLinkBetween removes either edge orientation', () async {
    await db.insertLink('first', 'a', 'b', 1);
    await db.insertLink('second', 'b', 'a', 2);

    await db.softDeleteLinkBetween('a', 'b');

    expect(await db.allActiveLinks(), isEmpty);
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
}
