import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/windows/graph_window.dart';

import 'fixtures/overview_demo_fixture.dart';

void main() {
  testWidgets('mixed work and personal notes form a readable overview', (
    tester,
  ) async {
    final koreanFont = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
    String? demoFontFamily;
    if (koreanFont.existsSync()) {
      final fontBytes = koreanFont.readAsBytesSync();
      await (FontLoader(
        'DemoKorean',
      )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
      demoFontFamily = 'DemoKorean';
    }
    var flutterRoot = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      flutterRoot = flutterRoot.parent;
    }
    final iconBytes = File(
      '${flutterRoot.path}/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
    const multiWindow = MethodChannel('mixin.one/desktop_multi_window');
    const multiWindowChannels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(multiWindow, (call) async {
      if (call.method == 'getWindowDefinition') {
        return {'windowId': 'overview-demo', 'windowArgument': ''};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(multiWindowChannels, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(multiWindow, null));
    addTearDown(
      () => messenger.setMockMethodCallHandler(multiWindowChannels, null),
    );
    await tester.binding.setSurfaceSize(const Size(720, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OverviewWindowApp(
        notes: overviewDemoNotes,
        edges: overviewDemoEdges,
        groups: overviewDemoGroups,
        suggestedGroups: overviewDemoSuggestions,
        modelReady: true,
        modelIndexed: overviewDemoNotes.length,
        modelIndexTotal: overviewDemoNotes.length,
        fontFamily: demoFontFamily,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오로라 출시 준비'), findsOneWidget);
    expect(find.text('채용 프로세스 개선'), findsOneWidget);
    expect(find.text('개인 생활'), findsOneWidget);
    expect(find.textContaining('키워드가 겹쳐요'), findsOneWidget);
    expect(find.text('연결 · 회의 · 환불 고객 인터뷰 요약'), findsOneWidget);

    expect(find.byType(OverviewWindow), findsOneWidget);
    if (Platform.environment['UPDATE_DEMO_GOLDEN'] == '1') {
      await expectLater(
        find.byType(OverviewWindow),
        matchesGoldenFile('goldens/overview_mixed_notes.png'),
      );
    }
  });
}
