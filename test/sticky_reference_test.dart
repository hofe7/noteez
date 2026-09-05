import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/windows/sticky_window.dart';

void main() {
  testWidgets(
    'related notes can be opened and kept as references without grouping',
    (tester) async {
      const windows = MethodChannel('mixin.one/desktop_multi_window');
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      const native = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final actions = <String>[];
      var kept = false;
      messenger.setMockMethodCallHandler(
        windows,
        (call) async => call.method == 'getWindowDefinition'
            ? {'windowId': 'reference-test', 'windowArgument': ''}
            : null,
      );
      messenger.setMockMethodCallHandler(native, (_) async => null);
      messenger.setMockMethodCallHandler(channels, (call) async {
        if (call.method != 'invokeMethod') return null;
        final data = call.arguments as Map;
        final method = data['method'] as String;
        if (method == ToMain.getConnection) {
          return jsonEncode({
            'links': kept
                ? [
                    {'id': 'other', 'preview': '인증 오류 해결 방법'},
                  ]
                : [],
            'suggestion': kept
                ? null
                : {
                    'id': 'other',
                    'preview': '인증 오류 해결 방법',
                    'full': '인증 토큰의 만료 시간을 확인한다.',
                    'reasons': ['주제가 비슷해요'],
                  },
          });
        }
        actions.add(method);
        if (method == ToMain.linkStickies) kept = true;
        if (method == ToMain.unlinkStickies) kept = false;
        return null;
      });
      for (final channel in [windows, channels, native]) {
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      await tester.pumpWidget(
        StickyWindowApp(
          initial: makeSticky(
            x: 0,
            y: 0,
            blocks: [textBlock('고객 A 로그인 오류 회의')],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.tap(find.text('관련 메모: 인증 오류 해결 방법'));
      await tester.pump();
      expect(find.text('주제가 비슷해요'), findsOneWidget);
      await tester.tap(find.text('메모 열기'));
      await tester.pump();
      expect(actions, contains(ToMain.focusSticky));
      await tester.tap(find.text('유지'));
      await tester.pump();
      expect(find.text('참고 메모 1'), findsOneWidget);
      expect(find.textContaining('관련 메모:'), findsNothing);
      expect(actions, contains(ToMain.linkStickies));
      expect(actions, isNot(contains(ToMain.createNoteGroup)));
      expect(actions, isNot(contains(ToMain.assignNotesToGroup)));
      await tester.tap(find.text('참고 메모 1'));
      await tester.pump();
      await tester.tap(find.byTooltip('참고 메모에서 해제'));
      await tester.pump();
      expect(actions, contains(ToMain.unlinkStickies));
      expect(find.textContaining('관련 메모:'), findsOneWidget);
      await tester.tap(find.text('연결·묶음'));
      await tester.pump();
      expect(actions, contains(ToMain.openOrganization));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
