import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/app_theme.dart';
import 'package:noteez/ipc.dart';
import 'package:noteez/windows/organize_dialog.dart';
import 'package:noteez/windows/graph_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mixin.one/desktop_multi_window/channels');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String?> membership;
  late bool linked;
  late bool created;
  late Map<String, String?> previous;
  late bool fail;
  late List<String> calls;
  setUp(() {
    created = false;
    membership = {'a': 'old', 'b': null};
    previous = Map.of(membership);
    linked = false;
    fail = false;
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'invokeMethod') return null;
      final args = call.arguments as Map;
      final method = args['method'] as String;
      if (method == ToMain.getOrganization) {
        return jsonEncode({
          'notes': [
            {'id': 'a', 'label': '회의 기록'},
            {'id': 'b', 'label': '배포 확인', 'text': '서버 점검 체크리스트'},
          ],
          'edges': [
            if (linked) {'a': 'a', 'b': 'b'},
          ],
          'groups': [
            for (final id in ['old', 'new', if (created) 'created'])
              {
                'id': id,
                'name': id == 'old' ? '기존 업무' : '이번 주',
                'memberIds': membership.keys
                    .where((n) => membership[n] == id)
                    .toList(),
              },
          ],
        });
      }
      calls.add(method);
      if (fail) throw PlatformException(code: 'write_failed');
      if ([
        ToMain.createNoteGroup,
        ToMain.assignNotesToGroup,
        ToMain.removeNotesFromGroup,
      ].contains(method)) {
        previous = Map.of(membership);
      }
      if (method == ToMain.createNoteGroup) {
        created = true;
        final data = jsonDecode(args['arguments'] as String);
        for (final id in data['ids']) {
          membership[id as String] = 'created';
        }
        return jsonEncode({'groupId': 'created', 'undoToken': 'receipt'});
      }
      if (method == ToMain.linkStickies) linked = true;
      if (method == ToMain.unlinkStickies) linked = false;
      if (method == ToMain.assignNotesToGroup) {
        final data = jsonDecode(args['arguments'] as String);
        for (final id in data['ids']) {
          membership[id as String] = data['groupId'] as String;
        }
      }
      if (method == ToMain.undoGroupChange) {
        expect(args['arguments'], 'receipt');
        created = false;
        membership = Map.of(previous);
      }
      if ([
        ToMain.assignNotesToGroup,
        ToMain.removeNotesFromGroup,
      ].contains(method)) {
        return jsonEncode({'undoToken': 'receipt'});
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  Future<void> open(WidgetTester tester, List<String> ids) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(460, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? family;
    if (Platform.environment['UPDATE_ORGANIZE_GOLDEN'] == '1') {
      family = 'OrganizeKorean';
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
    await tester.pumpWidget(
      MaterialApp(
        theme: noteezTheme(fontFamily: family),
        home: Scaffold(body: OrganizeDialog(noteIds: ids)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search manually connects, unlinks and undoes without grouping', (
    tester,
  ) async {
    await open(tester, ['a']);
    if (Platform.environment['UPDATE_ORGANIZE_GOLDEN'] == '1') {
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/organize_groups.png'),
      );
    }
    await tester.tap(find.text('연결').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '서버');
    await tester.pumpAndSettle();
    expect(find.text('배포 확인'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '연결').last);
    await tester.pumpAndSettle();
    expect(linked, isTrue);
    expect(calls, [ToMain.linkStickies]);
    await tester.tap(find.text('해제'));
    await tester.pumpAndSettle();
    expect(linked, isFalse);
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(linked, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('bulk move restores separate original memberships on undo', (
    tester,
  ) async {
    await open(tester, ['a', 'b']);
    await tester.tap(find.text('이번 주'));
    await tester.pumpAndSettle();
    expect(membership, {'a': 'new', 'b': 'new'});
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(membership, {'a': 'old', 'b': null});
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed mutation keeps membership and allows retry', (
    tester,
  ) async {
    await open(tester, ['a']);
    fail = true;
    await tester.tap(find.text('이번 주'));
    await tester.pumpAndSettle();
    expect(membership['a'], 'old');
    expect(find.textContaining('변경하지 못했어요'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('이번 주'));
    await tester.pumpAndSettle();
    expect(membership['a'], 'new');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'create from a single note and undo restores its previous group',
    (tester) async {
      await open(tester, ['a']);
      await tester.tap(find.text('새 묶음 만들기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '새 묶음 이름'),
        '새 프로젝트',
      );
      await tester.pump();
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();
      expect(membership['a'], 'created');
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(membership['a'], 'old');
      expect(created, isFalse);
      tester.view.physicalSize = const Size(360, 540);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('overview selection opens bulk organization without a model', (
    tester,
  ) async {
    const windows = MethodChannel('mixin.one/desktop_multi_window');
    messenger.setMockMethodCallHandler(
      windows,
      (call) async => call.method == 'getWindowDefinition'
          ? {'windowId': 'organize-overview', 'windowArgument': ''}
          : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(windows, null));
    await tester.binding.setSurfaceSize(const Size(460, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OverviewWindowApp(
        notes: [
          for (final id in ['a', 'b'])
            {
              'id': id,
              'label': '메모 $id',
              'color': 0,
              'open': true,
              'updatedAt': 0,
              'createdAt': 0,
            },
        ],
        edges: const [],
        suggestedGroups: const [],
        modelReady: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.text('묶음에 넣기·빼기'));
    await tester.pumpAndSettle();
    expect(find.text('2개 메모 정리'), findsOneWidget);
    await tester.tap(find.text('이번 주'));
    await tester.pumpAndSettle();
    expect(membership, {'a': 'new', 'b': 'new'});
    expect(tester.takeException(), isNull);
  });
}
