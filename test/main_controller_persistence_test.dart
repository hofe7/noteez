import 'dart:convert';
import 'dart:async';
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
  Future<void> Function(Sticky)? deliver;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reminders = ReminderScheduler((_) {});
    deliver = null;
    controller = MainController(
      database: db,
      reminders: reminders,
      deliverReminder: (note) async {
        await deliver?.call(note);
      },
    );
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
  test(
    'delivery failure retains durable reservation, successful retry clears it',
    () async {
      final at = DateTime.now().millisecondsSinceEpoch - 1000;
      await call(ToMain.setReminder, jsonEncode({'id': note.id, 'at': at}));
      deliver = (_) async {
        throw StateError('notification and window failed');
      };
      await expectLater(
        controller.deliverDueReminder(note.id),
        throwsStateError,
      );
      expect((await db.allActive()).single.remindAt, at);
      deliver = (_) async {};
      await controller.deliverDueReminder(note.id);
      expect((await db.allActive()).single.remindAt, isNull);
    },
  );

  test(
    'in-flight delivery cannot clear a newer reservation, even at same timestamp',
    () async {
      final at = DateTime.now().millisecondsSinceEpoch - 1000;
      await call(ToMain.setReminder, jsonEncode({'id': note.id, 'at': at}));
      final gate = Completer<void>();
      deliver = (_) => gate.future;
      final firing = controller.deliverDueReminder(note.id);
      await call(ToMain.setReminder, jsonEncode({'id': note.id, 'at': at}));
      gate.complete();
      await firing;
      expect((await db.allActive()).single.remindAt, at);
    },
  );

  test(
    'failed acknowledgement preserves reservation after successful delivery',
    () async {
      final at = DateTime.now().millisecondsSinceEpoch - 1000;
      await call(ToMain.setReminder, jsonEncode({'id': note.id, 'at': at}));
      await failUpdates();
      await expectLater(
        controller.deliverDueReminder(note.id),
        throwsA(anything),
      );
      expect((await db.allActive()).single.remindAt, at);
    },
  );
  test(
    'shutdown does not acknowledge an in-flight delivery against a closed database',
    () async {
      final at = DateTime.now().millisecondsSinceEpoch - 1000;
      await call(ToMain.setReminder, jsonEncode({'id': note.id, 'at': at}));
      final gate = Completer<void>();
      deliver = (_) => gate.future;
      final firing = controller.deliverDueReminder(note.id);
      await controller.shutdown();
      gate.complete();
      await firing;
      expect(controller.stickies.single.remindAt, at);
    },
  );
}
