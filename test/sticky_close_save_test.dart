import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/windows/sticky_window.dart';

void main() {
  testWidgets(
    'close preserves failed edits and waits for a successful retry acknowledgement',
    (tester) async {
      final events = <String>[];
      final gate = Completer<void>();
      Map<String, dynamic>? saved;
      var fail = true;
      const multiWindow = MethodChannel('mixin.one/desktop_multi_window');
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      const native = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(multiWindow, (call) async {
        if (call.method == 'getWindowDefinition') {
          return {'windowId': 'sticky-save-test', 'windowArgument': ''};
        }
        return null;
      });
      messenger.setMockMethodCallHandler(channels, (call) async {
        if (call.method != 'invokeMethod') return null;
        final data = call.arguments as Map;
        if (data['method'] == ToMain.getConnection) {
          return jsonEncode({'links': [], 'suggestion': null});
        }
        if (data['method'] == ToMain.updateSticky) {
          saved =
              jsonDecode(data['arguments'] as String) as Map<String, dynamic>;
          events.add('saving');
          if (fail) throw PlatformException(code: 'SAVE_FAILED');
          await gate.future;
          events.add('saved');
        }
        if (data['method'] == ToMain.closeSticky) events.add('archive');
        return null;
      });
      messenger.setMockMethodCallHandler(native, (call) async {
        if (call.method == 'close') events.add('close');
        return null;
      });
      for (final channel in [multiWindow, channels, native]) {
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      await tester.pumpWidget(
        StickyWindowApp(
          initial: makeSticky(x: 0, y: 0, blocks: [textBlock('original')]),
        ),
      );
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(100, 20));
      await mouse.moveTo(const Offset(110, 20));
      await tester.pump();
      tester.widget<NoteEditor>(find.byType(NoteEditor)).onChanged([
        textBlock('last keystroke'),
      ]);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(events, ['saving']);
      expect(find.textContaining('메모를 저장하지 못했어요'), findsOneWidget);
      expect(
        ((saved!['blocks'] as List).single as Map)['text'],
        'last keystroke',
      );
      fail = false;
      await tester.tap(find.byTooltip('저장하고 보관'));
      await tester.pump();
      expect(events, ['saving', 'saving']);
      gate.complete();
      await tester.pump();
      expect(events, ['saving', 'saving', 'saved', 'archive', 'close']);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
