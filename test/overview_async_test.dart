import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/main_controller.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/ipc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'overview returns saved notes before recommendations and does not rerun for window movement',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gate = Completer<Map<String, dynamic>>();
      var requests = 0;
      final controller = MainController(
        database: db,
        recommend: (_) {
          requests++;
          return gate.future;
        },
      );
      addTearDown(() async {
        await controller.shutdown();
        controller.dispose();
      });
      final note = makeSticky(x: 0, y: 0, blocks: [textBlock('회의록')]);
      await db.upsert(note);
      controller.stickies.add(note);
      Future<Map<String, dynamic>> read() async =>
          jsonDecode(
                await controller.handleWindowCall(
                      const MethodCall(ToMain.getOverviewData),
                    )
                    as String,
              )
              as Map<String, dynamic>;
      final initial = await read();
      expect(initial['notes'], hasLength(1));
      expect(initial['recommendationsBusy'], isTrue);
      expect(initial['suggestedGroups'], isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(requests, 1);
      await controller.handleWindowCall(
        MethodCall(
          ToMain.updateSticky,
          jsonEncode(note.copyWith(x: 200, width: 380).toJson()),
        ),
      );
      await read();
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(requests, 1);
      gate.complete({
        'suggestedGroups': [],
        'referenceSuggestions': [],
        'additions': {},
      });
      await Future<void>.delayed(Duration.zero);
      final ready = await read();
      expect(ready['recommendationsBusy'], isFalse);
      expect(ready['revision'] as int, greaterThan(initial['revision'] as int));
    },
  );
}
