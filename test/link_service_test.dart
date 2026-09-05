import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/models/link_change.dart';
import 'package:noteez/services/link_service.dart';

void main() {
  late AppDatabase db;
  late LinkService links;
  late Sticky a, b;
  late List<bool> published;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    a = makeSticky(x: 0, y: 0);
    b = makeSticky(x: 0, y: 0);
    await db.upsert(a);
    await db.upsert(b);
    published = [];
    links = LinkService(db, publish: (_, _, linked) => published.add(linked));
  });
  tearDown(() async {
    await links.flush();
    await db.close();
  });

  test('concurrent add makes one row and only one undo receipt', () async {
    final results = await Future.wait([
      links.set(a.id, b.id, true),
      links.set(b.id, a.id, true),
    ]);
    expect(await db.allActiveLinks(), hasLength(1));
    expect(results.where((r) => r.undoToken != null), hasLength(1));
    await links.undo(results.first.undoToken!);
    expect(await db.allActiveLinks(), isEmpty);
    await expectLater(
      links.undo(results.first.undoToken!),
      throwsA(isA<LinkChangeConflict>()),
    );
  });
  test(
    'remove and re-add invalidates the old receipt even though state matches',
    () async {
      final first = await links.set(a.id, b.id, true);
      await links.set(a.id, b.id, false);
      await links.set(a.id, b.id, true);
      await expectLater(
        links.undo(first.undoToken!),
        throwsA(isA<LinkChangeConflict>()),
      );
      expect(await db.allActiveLinks(), hasLength(1));
    },
  );
  test('trash and restore cannot revive an obsolete undo', () async {
    final first = await links.set(a.id, b.id, true);
    await db.trashNote(a.id);
    await db.restoreTrashed(a.id);
    await expectLater(
      links.undo(first.undoToken!),
      throwsA(isA<LinkChangeConflict>()),
    );
    expect(await db.allActiveLinks(), isEmpty);
  });
  test('failed write publishes nothing, failed undo remains retryable', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_link BEFORE INSERT ON links BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(links.set(a.id, b.id, true), throwsA(anything));
    expect(published, isEmpty);
    await db.customStatement('DROP TRIGGER fail_link');
    final change = await links.set(a.id, b.id, true);
    await db.customStatement(
      "CREATE TRIGGER fail_unlink BEFORE UPDATE ON links BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(links.undo(change.undoToken!), throwsA(anything));
    expect(published, [true]);
    await db.customStatement('DROP TRIGGER fail_unlink');
    await links.undo(change.undoToken!);
    expect(await db.allActiveLinks(), isEmpty);
  });
}
