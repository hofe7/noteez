import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/windows/graph_window.dart';

void main() {
  testWidgets(
    'existing group offers explained addition, undo and persistent rejection',
    (tester) async {
      final calls = <Map>[];
      var failMove = false;
      var conflictUndo = false;
      const windowChannel = MethodChannel('mixin.one/desktop_multi_window');
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(windowChannel, (call) async {
        if (call.method == 'getWindowDefinition') {
          return {'windowId': 'addition-test', 'windowArgument': ''};
        }
        return null;
      });
      messenger.setMockMethodCallHandler(channels, (call) async {
        if (call.method == 'invokeMethod') {
          calls.add(call.arguments as Map);
          if ((call.arguments as Map)['method'] == ToMain.undoGroupChange &&
              conflictUndo) {
            throw PlatformException(code: 'group_conflict');
          }
          if ((call.arguments as Map)['method'] == ToMain.assignNotesToGroup) {
            if (failMove) throw PlatformException(code: 'write_failed');
            return jsonEncode({'undoToken': 'receipt'});
          }
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(windowChannel, null),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channels, null));
      await tester.binding.setSurfaceSize(const Size(600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? family;
      final font = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
      if (Platform.environment['UPDATE_ADDITION_GOLDEN'] == '1' &&
          font.existsSync()) {
        family = 'AdditionKorean';
        await (FontLoader(family)..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
      if (Platform.environment['UPDATE_ADDITION_GOLDEN'] == '1') {
        var flutterRoot = File(Platform.resolvedExecutable).parent;
        for (var i = 0; i < 5; i++) {
          flutterRoot = flutterRoot.parent;
        }
        final iconBytes = File(
          '${flutterRoot.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytesSync();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
      }
      Map<String, dynamic> note(String id, String label) => {
        'id': id,
        'label': label,
        'color': 0,
        'open': true,
        'updatedAt': DateTime(2026, 9, 5).millisecondsSinceEpoch,
        'createdAt': DateTime(2026, 9, 1).millisecondsSinceEpoch,
      };
      await tester.pumpWidget(
        OverviewWindowApp(
          fontFamily: family,
          notes: [
            note('a', '오로라 가입 첫 화면 개선'),
            note('new', '오로라 신규 고객 안내 문구 줄이기'),
          ],
          edges: const [],
          suggestedGroups: const [],
          groups: const [
            {
              'id': 'launch',
              'name': '오로라 출시 준비',
              'collapsed': false,
              'memberIds': ['a'],
              'suggestions': [
                {
                  'noteId': 'new',
                  'score': 0.82,
                  'reasons': ['표현은 달라도 의미가 가까워요'],
                },
              ],
            },
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이 묶음에 추가할까요?'), findsOneWidget);
      expect(find.text('표현은 달라도 의미가 가까워요'), findsOneWidget);
      expect(
        calls.where((call) => call['method'] == ToMain.assignNotesToGroup),
        isEmpty,
      );
      if (Platform.environment['UPDATE_ADDITION_GOLDEN'] == '1') {
        await expectLater(
          find.byType(OverviewWindow),
          matchesGoldenFile('goldens/overview_group_addition.png'),
        );
      }
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
      final assignment = calls.singleWhere(
        (call) => call['method'] == ToMain.assignNotesToGroup,
      );
      expect(jsonDecode(assignment['arguments'] as String), {
        'groupId': 'launch',
        'ids': ['new'],
      });
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(
        calls.any((call) => call['method'] == ToMain.undoGroupChange),
        isTrue,
      );
      await tester.tap(find.byTooltip('이 묶음에 추천하지 않기'));
      await tester.pumpAndSettle();
      final dismissal = calls.singleWhere(
        (call) => call['method'] == ToMain.dismissGroupSuggestion,
      );
      expect(jsonDecode(dismissal['arguments'] as String), {
        'noteId': 'new',
        'groupId': 'launch',
      });
      await tester.tap(find.byTooltip('묶음 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('숨긴 추가 추천 다시 보기'));
      await tester.pumpAndSettle();
      expect(
        calls.any((call) => call['method'] == ToMain.resetGroupSuggestions),
        isTrue,
      );
      failMove = true;
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
      expect(find.text('변경하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      failMove = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      conflictUndo = true;
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(calls.last['method'], ToMain.undoGroupChange);
      expect(find.textContaining('다른 변경이 있어'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
