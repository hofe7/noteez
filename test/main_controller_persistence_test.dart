import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/main_controller.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/models/group_change.dart';
import 'package:noteez/reminder/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MainController controller;
  late ReminderScheduler reminders;
  late Sticky note;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reminders = ReminderScheduler((_) {});
    controller = MainController(database: db, reminders: reminders);
    note = makeSticky(x: 0, y: 0, blocks: [textBlock('original')]);
    await db.upsert(note);
    controller.stickies.add(note);
  });
  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
  });
  Future<dynamic> call(String method, [Object? arguments]) =>
      controller.handleWindowCall(MethodCall(method, arguments));
  Future<void> failUpdates() => db.customStatement(
    "CREATE TRIGGER fail_save BEFORE UPDATE ON stickies BEGIN SELECT RAISE(ABORT, 'disk full'); END",
  );

  test(
    'IPC save failure keeps controller and database aligned, retry succeeds',
    () async {
      final edited = note.copyWith(blocks: [textBlock('edited')]);
      await failUpdates();
      await expectLater(
        call(ToMain.updateSticky, jsonEncode(edited.toJson())),
        throwsA(anything),
      );
      expect(controller.stickies.single.preview, 'original');
      expect((await db.allActive()).single.preview, 'original');
      await db.customStatement('DROP TRIGGER fail_save');
      await call(ToMain.updateSticky, jsonEncode(edited.toJson()));
      expect(controller.stickies.single.preview, 'edited');
      expect((await db.allActive()).single.preview, 'edited');
    },
  );
  test(
    'failed reminder cancellation preserves the existing timer and saved reminder',
    () async {
      final at = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await call(ToMain.setReminder, jsonEncode({'id': note.id, 'at': at}));
      expect(reminders.isScheduled(note.id), isTrue);
      await failUpdates();
      await expectLater(call(ToMain.clearReminder, note.id), throwsA(anything));
      expect(reminders.isScheduled(note.id), isTrue);
      expect(controller.stickies.single.remindAt, at);
      await db.customStatement('DROP TRIGGER fail_save');
      await call(
        ToMain.updateSticky,
        jsonEncode(note.copyWith(blocks: [textBlock('editor')]).toJson()),
      );
      expect((await db.allActive()).single.remindAt, at);
      await call(ToMain.clearReminder, note.id);
      expect(reminders.isScheduled(note.id), isFalse);
      expect((await db.allActive()).single.remindAt, isNull);
    },
  );
  test('trash then a late editor update cannot recreate content', () async {
    await call(ToMain.deleteSticky, note.id);
    await call(ToMain.updateSticky, jsonEncode(note.toJson()));
    expect(controller.stickies, isEmpty);
    expect(await db.allActive(), isEmpty);
    await call(ToMain.restoreTrashed, note.id);
    expect(controller.stickies.single.open, isFalse);
    expect((await db.allActive()).single.preview, 'original');
  });
  test(
    'group IPC returns receipts and maps stale undo to a conflict',
    () async {
      final created = GroupChange.decode(
        await call(
          ToMain.createNoteGroup,
          jsonEncode({
            'name': 'A',
            'ids': [note.id],
          }),
        ),
      );
      final second = GroupChange.decode(
        await call(
          ToMain.createNoteGroup,
          jsonEncode({
            'name': 'B',
            'ids': [note.id],
          }),
        ),
      );
      await expectLater(
        call(ToMain.undoGroupChange, created.undoToken),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'group_conflict',
          ),
        ),
      );
      expect((await db.allGroupMembers()).single.groupId, second.groupId);
      await call(ToMain.undoGroupChange, second.undoToken);
      expect((await db.allGroupMembers()).single.groupId, created.groupId);
    },
  );
}
