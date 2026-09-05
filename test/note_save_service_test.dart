import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/services/note_save_service.dart';

void main() {
  test(
    'failed persistence does not publish, and the queue accepts a retry',
    () async {
      final before = makeSticky(x: 0, y: 0, blocks: [textBlock('before')]);
      var current = before;
      var fail = true;
      final after = before.copyWith(blocks: [textBlock('after')]);
      final service = NoteSaveService(
        read: (_) => current,
        persist: (_) async {
          if (fail) throw StateError('disk');
          return true;
        },
        publish: (n) => current = n,
      );
      await expectLater(service.save(after), throwsStateError);
      expect(current.blocks.single.text, 'before');
      fail = false;
      await service.save(after);
      expect(current.blocks.single.text, 'after');
    },
  );
  test(
    'metadata updates use the latest committed content, never an old snapshot',
    () async {
      var current = makeSticky(x: 0, y: 0, blocks: [textBlock('before')]);
      final gate = Completer<void>();
      final written = <Sticky>[];
      final service = NoteSaveService(
        read: (_) => current,
        persist: (n) async {
          await gate.future;
          written.add(n);
          return true;
        },
        publish: (n) => current = n,
      );
      final saving = service.save(
        current.copyWith(blocks: [textBlock('edited')]),
      );
      final closing = service.update(
        current.id,
        (n) => n.copyWith(open: false),
      );
      expect(current.blocks.single.text, 'before');
      gate.complete();
      await Future.wait([saving, closing]);
      expect(written.last.blocks.single.text, 'edited');
      expect(current.open, isFalse);
    },
  );
  test('conditional update cannot recreate deleted or missing notes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final note = makeSticky(x: 0, y: 0, blocks: [textBlock('original')]);
    await db.upsert(note);
    await db.trashNote(note.id);
    final published = <Sticky>[];
    final service = NoteSaveService(
      read: (_) => note,
      persist: db.updateExisting,
      publish: published.add,
    );
    await service.save(note.copyWith(blocks: [textBlock('late edit')]));
    expect(published, isEmpty);
    expect(await db.allActive(), isEmpty);
    expect((await db.allTrashed()).single.blocksJson, contains('original'));
    await db.permanentlyDeleteTrashed(note.id);
    await service.save(note);
    expect(await db.allActive(), isEmpty);
    expect(published, isEmpty);
  });
}
