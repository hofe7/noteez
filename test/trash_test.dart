import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/windows/trash_dialog.dart';

void main() {
  test(
    'trash survives storage, restores content and timestamps without alarms',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final note = makeSticky(
        x: 20,
        y: 30,
        blocks: [textBlock('마지막 편집')],
      ).copyWith(remindAt: DateTime(2030).millisecondsSinceEpoch);
      await db.upsert(note);
      await db.insertLink('link', note.id, 'other', 0);
      await db.upsertEmbedding(note.id, 'model', 'hash', '[1,0]');
      await db.trashNote(note.id);
      expect(await db.allActive(), isEmpty);
      expect((await db.allTrashed()).single.id, note.id);
      expect(await db.allActiveLinks(), isEmpty);
      expect(await db.allEmbeddingsForModel('model'), isEmpty);
      final restored = (await db.restoreTrashed(note.id))!;
      expect(restored.blocks.single.text, '마지막 편집');
      expect(
        restored.contentUpdatedAt.millisecondsSinceEpoch,
        note.contentUpdatedAt.millisecondsSinceEpoch,
      );
      expect(restored.open, false);
      expect(restored.remindAt, isNull);
      expect(await db.allTrashed(), isEmpty);
      expect(await db.restoreTrashed(note.id), isNull);
      await db.permanentlyDeleteTrashed(note.id);
      expect(await db.allActive(), hasLength(1));
      await db.trashNote(note.id);
      await db.permanentlyDeleteTrashed(note.id);
      expect(await db.allTrashed(), isEmpty);
      expect(await db.restoreTrashed(note.id), isNull);
      expect(await db.select(db.links).get(), isEmpty);
    },
  );

  test('trash persists after reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp('noteez-trash-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(file));
    final note = makeSticky(x: 0, y: 0);
    await db.upsert(note);
    await db.trashNote(note.id);
    await db.close();
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    expect((await reopened.allTrashed()).single.id, note.id);
    expect(await reopened.allActive(), isEmpty);
    expect((await reopened.restoreTrashed(note.id))!.id, note.id);
  });

  test('trash transaction rolls back on cleanup failure', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final note = makeSticky(x: 0, y: 0);
    await db.upsert(note);
    await db.upsertEmbedding(note.id, 'model', 'hash', '[1,0]');
    await db.customStatement(
      "CREATE TRIGGER reject_cleanup BEFORE DELETE ON embeddings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(db.trashNote(note.id), throwsA(anything));
    expect(await db.allActive(), hasLength(1));
    expect(await db.allTrashed(), isEmpty);
  });

  testWidgets(
    'trash requires confirmation for permanent deletion and supports restore',
    (tester) async {
      const channel = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      var notes = [
        {'id': 'a', 'text': '삭제한 메모', 'deletedAt': 1000},
      ];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'invokeMethod') return null;
        final method = (call.arguments as Map)['method'] as String;
        if (method == ToMain.getTrash) return jsonEncode(notes);
        calls.add(method);
        notes = [];
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TrashDialog())),
      );
      await tester.pumpAndSettle();
      expect(find.text('삭제한 메모'), findsOneWidget);
      await tester.tap(find.text('영구 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();
      expect(calls, [ToMain.restoreTrashed]);
      expect(find.text('휴지통이 비어 있습니다.'), findsOneWidget);
      notes = [
        {'id': 'b', 'text': '영구 삭제할 메모', 'deletedAt': 2000},
      ];
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TrashDialog())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('영구 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '영구 삭제'));
      await tester.pumpAndSettle();
      expect(calls, [ToMain.restoreTrashed, ToMain.permanentlyDeleteTrashed]);
      expect(find.text('휴지통이 비어 있습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
