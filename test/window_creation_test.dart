import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/main_controller.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent open requests create only one editor for a memo', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final controller = MainController(database: db);
    final note = makeSticky(x: 0, y: 0);
    await db.upsert(note);
    controller.stickies.add(note);
    final gate = Completer<String>();
    var creates = 0;
    const channel = MethodChannel('mixin.one/desktop_multi_window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createWindow') {
        creates++;
        return gate.future;
      }
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      controller.dispose();
      await db.close();
    });
    final first = controller.showOne(note.id);
    final second = controller.showOne(note.id);
    await Future<void>.delayed(Duration.zero);
    expect(creates, 1);
    gate.complete('one-window');
    await Future.wait([first, second]);
  });
}
