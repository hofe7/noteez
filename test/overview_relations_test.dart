import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/windows/graph_window.dart';
import 'package:noteez/windows/reference_list.dart';

void main() {
  testWidgets(
    'relations browse saved links and recommendations without grouping',
    (tester) async {
      final actions = <Map>[];
      const windows = MethodChannel('mixin.one/desktop_multi_window');
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        windows,
        (call) async => call.method == 'getWindowDefinition'
            ? {'windowId': 'relations-test', 'windowArgument': ''}
            : null,
      );
      messenger.setMockMethodCallHandler(channels, (call) async {
        if (call.method == 'invokeMethod') actions.add(call.arguments as Map);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(windows, null));
      addTearDown(() => messenger.setMockMethodCallHandler(channels, null));
      await tester.binding.setSurfaceSize(const Size(460, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? family;
      if (Platform.environment['UPDATE_RELATIONS_GOLDEN'] == '1') {
        family = 'RelationsKorean';
        await (FontLoader(family)..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    '/System/Library/Fonts/AppleSDGothicNeo.ttc',
                  ).readAsBytesSync(),
                ),
              ),
            ))
            .load();
        var root = File(Platform.resolvedExecutable).parent;
        for (var i = 0; i < 5; i++) {
          root = root.parent;
        }
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    '${root.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                  ).readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      Map<String, dynamic> note(String id, String title) => {
        'id': id,
        'label': title,
        'color': 0,
        'open': false,
        'createdAt': 0,
        'updatedAt': 0,
      };
      await tester.pumpWidget(
        OverviewWindowApp(
          fontFamily: family,
          notes: [
            note('a', '한빛 킥오프에서 합의한 것'),
            note('b', '첫 화면에서 샘플부터 보여주면 어떨까'),
            note('c', '시연 후 질문 세 개'),
          ],
          edges: const [
            {'a': 'a', 'b': 'b'},
            {'a': 'b', 'b': 'a'},
            {'a': 'a', 'b': 'deleted'},
          ],
          suggestedGroups: const [],
          referenceSuggestions: const [
            {
              'a': 'a',
              'b': 'b',
              'reasons': ['already saved'],
            },
            {
              'a': 'b',
              'b': 'c',
              'reasons': ['고객 도입 업무가 비슷해요'],
            },
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.text('관계'));
      await tester.pumpAndSettle();
      expect(find.text('저장한 참고 관계 1개'), findsOneWidget);
      expect(find.text('관련 메모 추천 1개'), findsOneWidget);
      expect(find.text('already saved'), findsNothing);
      expect(find.text('선택'), findsNothing);
      if (Platform.environment['UPDATE_RELATIONS_GOLDEN'] == '1') {
        await expectLater(
          find.byType(OverviewWindow),
          matchesGoldenFile('goldens/overview_relations.png'),
        );
      }
      await tester.tap(find.text('참고로 유지'));
      await tester.pump();
      expect(actions.last['method'], ToMain.linkStickies);
      expect(jsonDecode(actions.last['arguments'] as String), {
        'a': 'b',
        'b': 'c',
      });
      await tester.tap(find.text('추천 숨기기'));
      await tester.pump();
      expect(actions.last['method'], ToMain.dismissSuggestions);
      await tester.tap(find.text('참고 관계 해제'));
      await tester.pump();
      expect(actions.last['method'], ToMain.unlinkStickies);
      await tester.tap(find.text('한빛 킥오프에서 합의한 것'));
      await tester.pump();
      expect(actions.last['method'], ToMain.focusSticky);
      expect(actions.any((a) => a['method'] == ToMain.createNoteGroup), false);
      await tester.enterText(find.byType(TextField), '시연 후');
      await tester.pump();
      expect(find.text('현재 필터에 맞는 참고 관계가 없습니다.'), findsOneWidget);
      expect(find.text('첫 화면에서 샘플부터 보여주면 어떨까'), findsOneWidget);
      await tester.tap(find.text('묶음'));
      await tester.pump();
      expect(find.text('선택'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed reference mutation keeps the pair visible for retry', (
    tester,
  ) async {
    const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var fail = true;
    messenger.setMockMethodCallHandler(channels, (call) async {
        if (call.method == 'invokeMethod' && fail) {
          throw PlatformException(code: 'DB_FAILURE');
        }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channels, null));
    final notes = <Map<String, dynamic>>[
      {'id': 'a', 'label': '회의록'},
      {'id': 'b', 'label': '해결 방법'},
    ];
    Widget app(List<Map<String, dynamic>> edges) => MaterialApp(
      home: Scaffold(
        body: ReferenceList(
          notes: notes,
          edges: edges,
          suggestions: const [],
          matches: (_) => true,
        ),
      ),
    );
    await tester.pumpWidget(
      app([
        {'a': 'a', 'b': 'b'},
      ]),
    );
    await tester.pump();
    await tester.tap(find.text('참고 관계 해제'));
    await tester.pump();
    expect(find.textContaining('관계를 변경하지 못했습니다'), findsOneWidget);
    expect(find.text('저장한 참고 관계 1개'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('참고 관계 해제'));
    await tester.pump();
    // Simulate the authoritative overview refresh after the successful write.
    await tester.pumpWidget(app([]));
    await tester.pump();
    expect(find.text('저장한 참고 관계 0개'), findsOneWidget);
    expect(find.text('참고 관계 해제'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
