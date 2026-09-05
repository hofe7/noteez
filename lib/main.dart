import 'app_theme.dart';
import 'windows/organize_dialog.dart';
import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'backup/backup_service.dart';
import 'main_controller.dart';
import 'menubar.dart';
import 'models/sticky.dart';
import 'report.dart';
import 'sticky_window_sizing.dart';
import 'windows/backup_window.dart';
import 'windows/control_window.dart';
import 'windows/graph_window.dart' show OverviewWindowApp;
import 'windows/model_window.dart';
import 'windows/report_window.dart';
import 'windows/search_palette.dart';
import 'windows/sticky_window.dart';

/// 모든 창(메인/스티커)이 main()을 돈다. fromCurrentEngine().arguments 로 구분.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final wc = await WindowController.fromCurrentEngine();
  final argStr = wc.arguments;

  if (argStr.isEmpty) {
    final backups = BackupService();
    try {
      await backups.applyPendingRestore();
    } catch (e) {
      // A restore filesystem problem must not make the note app unlaunchable.
      debugPrint('startup restore failed: $e');
    }
    // 메인 = 권위자. DB 로드 + 스티커 창 생성.
    await mainController.start();
    // Images can make a backup large, so launch first and snapshot in the
    // background. SQLite's backup API still gives us a consistent live copy.
    unawaited(
      backups.createAutomaticBackup().catchError((Object e) {
        debugPrint('startup backup failed: $e');
        return null;
      }),
    );

    // 메뉴바 + 글로벌 핫키. 성공하면 컨트롤 창 없이 숨김(메뉴바 앱).
    // 실패하면 안전하게 컨트롤 창으로 폴백(메모 추가 수단 보장).
    var trayOk = true;
    try {
      await menubar.init();
    } catch (e) {
      trayOk = false;
      debugPrint('menubar init failed, falling back to control window: $e');
    }

    if (trayOk) {
      // 메인 창 = 검색 팔레트(Spotlight식). 평소 숨김, ⌘⇧K 로 표시.
      windowManager.waitUntilReadyToShow(
        const WindowOptions(
          size: Size(560, 440),
          center: true,
          backgroundColor: Colors.transparent,
          titleBarStyle: TitleBarStyle.hidden,
          windowButtonVisibility: false,
          skipTaskbar: true,
        ),
        () async {
          await windowManager.setAsFrameless();
          await windowManager.setBackgroundColor(Colors.transparent);
          await windowManager.hide();
        },
      );
      runApp(const SearchPaletteApp());
    } else {
      windowManager.waitUntilReadyToShow(
        const WindowOptions(size: Size(360, 420), center: true),
        () async {
          await windowManager.setTitle('Noteez');
          await windowManager.show();
        },
      );
      runApp(const ControlWindow());
    }
    return;
  }

  final m = jsonDecode(argStr) as Map<String, dynamic>;

  if (m['kind'] == 'organize') {
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(460, 640),
        minimumSize: Size(360, 540),
        center: true,
      ),
      () async {
        await windowManager.setTitle('Noteez · 연결·묶음');
        await windowManager.show();
      },
    );
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: noteezTheme(),
        home: Scaffold(
          body: Center(
            child: OrganizeDialog(
              noteIds: [m['noteId'] as String],
              onDone: () {
                windowManager.close();
              },
            ),
          ),
        ),
      ),
    );
    return;
  }

  // 리포트 창
  if (m['kind'] == 'report') {
    final data = ReportData.fromJson(m['data'] as Map<String, dynamic>);
    windowManager.waitUntilReadyToShow(
      const WindowOptions(size: Size(460, 600), center: true),
      () async {
        await windowManager.setTitle('Noteez · 내가 한 일');
        await windowManager.show();
      },
    );
    runApp(ReportWindowApp(data: data));
    return;
  }

  // 전체 보기 창 (묶음 + 그 외 + 서랍)
  if (m['kind'] == 'overview') {
    final notes = (m['notes'] as List).cast<Map<String, dynamic>>();
    final edges = (m['edges'] as List).cast<Map<String, dynamic>>();
    final suggestedGroups = ((m['suggestedGroups'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final groups = ((m['groups'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final notice = m['notice'] as String?;
    final modelReady = m['modelReady'] as bool? ?? true;
    final modelIndexed = m['modelIndexed'] as int? ?? 0;
    final modelIndexTotal = m['modelIndexTotal'] as int? ?? 0;
    windowManager.waitUntilReadyToShow(
      const WindowOptions(size: Size(460, 640), center: true),
      () async {
        await windowManager.setTitle('Noteez · 전체 보기');
        await windowManager.show();
      },
    );
    runApp(
      OverviewWindowApp(
        notes: notes,
        edges: edges,
        suggestedGroups: suggestedGroups,
        referenceSuggestions: ((m['referenceSuggestions'] as List?) ?? const [])
            .cast<Map<String, dynamic>>(),
        groups: groups,
        notice: notice,
        modelReady: modelReady,
        recommendationsBusy: m['recommendationsBusy'] == true,
        recommendationError: m['recommendationError'] as String?,
        modelIndexed: modelIndexed,
        modelIndexTotal: modelIndexTotal,
      ),
    );
    return;
  }

  if (m['kind'] == 'models') {
    final state = m['state'] as Map<String, dynamic>;
    windowManager.waitUntilReadyToShow(
      const WindowOptions(size: Size(560, 620), center: true),
      () async {
        await windowManager.setTitle('Noteez · AI 모델');
        await windowManager.show();
      },
    );
    runApp(ModelWindowApp(initialState: state));
    return;
  }

  if (m['kind'] == 'backups') {
    final state = m['state'] as Map<String, dynamic>;
    windowManager.waitUntilReadyToShow(
      const WindowOptions(size: Size(560, 640), center: true),
      () async {
        await windowManager.setTitle('Noteez · 백업');
        await windowManager.show();
      },
    );
    runApp(BackupWindowApp(initialState: state));
    return;
  }

  // 스티커 창
  final sticky = Sticky.fromJson(m);
  final focusOnOpen = m['focusOnOpen'] == true; // 검색/소환으로 열림 → 바로 편집
  final opts = WindowOptions(
    size: StickyWindowSizing.initialSize(sticky),
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setPosition(Offset(sticky.x, sticky.y));
    await windowManager.setHasShadow(true);
    await windowManager.show();
    if (focusOnOpen) await windowManager.focus();
  });
  runApp(StickyWindowApp(initial: sticky, focusOnOpen: focusOnOpen));
}
