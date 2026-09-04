import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'main_controller.dart';

/// 메뉴바 아이콘 + 글로벌 핫키. 임시 컨트롤 창을 대체한다.
/// ⌘⇧N 새 메모 / ⌘⇧S 모든 스티커 보이기.
class MenubarController with TrayListener {
  Future<void> init() async {
    mainController.onRestartRequested = _restart;
    trayManager.addListener(this);
    await trayManager.setIcon('assets/icons/tray.png', isTemplate: true);
    await trayManager.setToolTip('Noteez');
    await trayManager.setContextMenu(_menu());

    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => mainController.addSticky(),
    );
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => mainController.showAll(),
    );
    // ⌘⇧K : 검색 팔레트
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => mainController.openSearch(),
    );
    // ⌘⇧R : "내가 한 일" 보고
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyR,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => mainController.openReport(),
    );
    // ⌘⇧Space : 빠른 캡처 바
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => mainController.openCapture(),
    );
    // ⌘⇧G : 지식 그래프
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyG,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => mainController.openOverview(),
    );
  }

  Menu _menu() => Menu(
    items: [
      MenuItem(key: 'new', label: '새 메모   ⌘⇧N'),
      MenuItem(key: 'capture', label: '빠른 캡처   ⌘⇧Space'),
      MenuItem(key: 'search', label: '검색   ⌘⇧K'),
      MenuItem(key: 'report', label: '내가 한 일   ⌘⇧R'),
      MenuItem(key: 'graph', label: '전체 보기   ⌘⇧G'),
      MenuItem(key: 'showAll', label: '모든 스티커 보이기   ⌘⇧S'),
      MenuItem.separator(),
      MenuItem(key: 'importMarkdown', label: 'Markdown 파일 가져오기…'),
      MenuItem(key: 'importMarkdownFolder', label: 'Markdown 폴더 가져오기…'),
      MenuItem(key: 'importNotionZip', label: 'Notion ZIP 가져오기…'),
      MenuItem(key: 'exportMarkdown', label: '모든 메모를 Markdown으로 내보내기…'),
      MenuItem.separator(),
      MenuItem(key: 'exportBackup', label: 'Noteez 백업 저장…'),
      MenuItem(key: 'restoreBackup', label: 'Noteez 백업에서 복원…'),
      MenuItem(key: 'backups', label: '자동 백업 관리…'),
      MenuItem.separator(),
      MenuItem(key: 'models', label: 'AI 연결 모델…'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Noteez 종료'),
    ],
  );

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'new':
        mainController.addSticky();
      case 'capture':
        mainController.openCapture();
      case 'search':
        mainController.openSearch();
      case 'report':
        mainController.openReport();
      case 'graph':
        mainController.openOverview();
      case 'showAll':
        mainController.showAll();
      case 'importMarkdown':
        unawaited(_importFiles());
      case 'importMarkdownFolder':
        unawaited(_importFolder());
      case 'importNotionZip':
        unawaited(_importNotionZip());
      case 'exportMarkdown':
        unawaited(_exportAll());
      case 'exportBackup':
        unawaited(_exportBackup());
      case 'restoreBackup':
        unawaited(_restoreBackup());
      case 'backups':
        mainController.openBackups();
      case 'models':
        mainController.openModels();
      case 'quit':
        _quit();
    }
  }

  Future<void> _importFiles() async {
    try {
      final result = await mainController.importMarkdownFiles();
      if (result != null) {
        await _flashStatus(
          'Markdown ${result.imported}개 가져옴'
          '${result.updated == 0 ? '' : ' · ${result.updated}개 갱신'}'
          '${result.skipped == 0 ? '' : ' · ${result.skipped}개 중복 건너뜀'}'
          '${result.conflicted == 0 ? '' : ' · ${result.conflicted}개 충돌 보존'}'
          '${result.linked == 0 ? '' : ' · 연결 ${result.linked}개'}'
          '${result.failed == 0 ? '' : ' · ${result.failed}개 실패'}',
        );
      }
    } catch (e) {
      debugPrint('Markdown import failed: $e');
      await _flashStatus('Markdown 가져오기 실패');
    }
  }

  Future<void> _importFolder() async {
    try {
      final result = await mainController.importMarkdownFolder();
      if (result != null) {
        await _flashStatus(
          'Markdown ${result.imported}개 가져옴'
          '${result.updated == 0 ? '' : ' · ${result.updated}개 갱신'}'
          '${result.skipped == 0 ? '' : ' · ${result.skipped}개 중복 건너뜀'}'
          '${result.conflicted == 0 ? '' : ' · ${result.conflicted}개 충돌 보존'}'
          '${result.linked == 0 ? '' : ' · 연결 ${result.linked}개'}'
          '${result.failed == 0 ? '' : ' · ${result.failed}개 실패'}',
        );
      }
    } catch (e) {
      debugPrint('Markdown folder import failed: $e');
      await _flashStatus('Markdown 폴더 가져오기 실패');
    }
  }

  Future<void> _importNotionZip() async {
    try {
      final result = await mainController.importNotionZip();
      if (result != null) {
        await _flashStatus(
          'Notion ${result.imported}개 가져옴'
          '${result.updated == 0 ? '' : ' · ${result.updated}개 갱신'}'
          '${result.skipped == 0 ? '' : ' · ${result.skipped}개 중복 건너뜀'}'
          '${result.conflicted == 0 ? '' : ' · ${result.conflicted}개 충돌 보존'}'
          '${result.linked == 0 ? '' : ' · 연결 ${result.linked}개'}'
          '${result.failed == 0 ? '' : ' · ${result.failed}개 실패'}',
        );
      }
    } catch (e) {
      debugPrint('Notion ZIP import failed: $e');
      await _flashStatus('Notion ZIP 가져오기 실패');
    }
  }

  Future<void> _exportAll() async {
    try {
      final result = await mainController.exportAllMarkdown();
      if (result == null) return;
      await Process.run('open', [result.directoryPath]);
      await _flashStatus('Markdown ${result.noteCount}개 내보냄');
    } catch (e) {
      debugPrint('Markdown export failed: $e');
      await _flashStatus('Markdown 내보내기 실패');
    }
  }

  Future<void> _exportBackup() async {
    try {
      final result = await mainController.exportBackup();
      if (result == null) return;
      await _flashStatus(
        '메모 ${result.noteCount}개 · 이미지 ${result.imageCount}개 백업 완료',
      );
    } catch (e) {
      debugPrint('Noteez backup failed: $e');
      await _flashStatus('Noteez 백업 실패');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await mainController.stageRestore();
      if (result == null) return;
      await trayManager.setToolTip(
        '메모 ${result.noteCount}개 복원 준비 완료 · Noteez 재시작 중',
      );
      await _restart();
    } catch (e) {
      debugPrint('Noteez restore failed: $e');
      await _flashStatus('Noteez 백업 복원 실패');
    }
  }

  Future<void> _flashStatus(String message) async {
    await trayManager.setToolTip(message);
    await Future<void>.delayed(const Duration(seconds: 2));
    await trayManager.setToolTip('Noteez');
  }

  Future<void> _quit() async {
    try {
      await hotKeyManager.unregisterAll();
      await trayManager.destroy();
    } catch (e) {
      debugPrint('menubar teardown: $e');
    }
    exit(0);
  }

  Future<void> _restart() async {
    try {
      await hotKeyManager.unregisterAll();
      await trayManager.destroy();
      await mainController.shutdown();
      final executable = File(Platform.resolvedExecutable);
      final appBundle = executable.parent.parent.parent.path;
      await Process.start('/bin/sh', [
        '-c',
        'sleep 1; /usr/bin/open -n -- "\$1"',
        'noteez-restart',
        appBundle,
      ], mode: ProcessStartMode.detached);
    } catch (e) {
      debugPrint('Noteez restart failed: $e');
    }
    exit(0);
  }
}

final menubar = MenubarController();
