import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/main_controller.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/models/saved_note_open_failure.dart';
import 'package:noteez/sticky_search.dart';
import 'package:noteez/windows/search_palette.dart';

class TestController extends MainController {
  TestController(AppDatabase database) : super(database: database);
  final requests = <String, Completer<SearchResult>>{};
  final saves = <String>[];
  bool failSave = true;
  bool failOpen = false;
  @override
  Future<SearchResult> search(String query) =>
      (requests[query] = Completer<SearchResult>()).future;
  @override
  Future<void> addStickyWithText(String text) async {
    saves.add(text);
    if (failSave) throw StateError('disk full');
    if (failOpen) throw const SavedNoteOpenFailure('saved');
  }
}

void main() {
  late AppDatabase db;
  late TestController controller;
  late List<String> nativeCalls;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    controller = TestController(db);
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          nativeCalls.add(call.method);
          return null;
        });
  });
  tearDown(() async {
    await db.close();
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });
  testWidgets('old semantic response cannot replace a newer search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SearchPalette(controller: controller)),
    );
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 150));
    controller.requests['new']!.complete((
      exact: [
        makeSticky(x: 0, y: 0, blocks: [textBlock('new result')]),
      ],
      related: <Sticky>[],
    ));
    await tester.pump();
    controller.requests['old']!.complete((
      exact: [
        makeSticky(x: 0, y: 0, blocks: [textBlock('old result')]),
      ],
      related: <Sticky>[],
    ));
    await tester.pump();
    expect(
      find.textContaining('new result', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('old result', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('capture failure keeps text visible and retries before hiding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SearchPalette(controller: controller)),
    );
    controller.captureTick.value++;
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'do not lose this');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.textContaining('입력은 그대로예요'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'do not lose this',
    );
    expect(nativeCalls, isNot(contains('hide')));
    controller.failSave = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.saves, ['do not lose this', 'do not lose this']);
    expect(nativeCalls, contains('hide'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('window failure after save cannot create a duplicate on retry', (
    tester,
  ) async {
    controller.failSave = false;
    controller.failOpen = true;
    await tester.pumpWidget(
      MaterialApp(home: SearchPalette(controller: controller)),
    );
    controller.captureTick.value++;
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'saved already');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.textContaining('메모는 저장했어요'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.saves, ['saved already']);
  });
}
