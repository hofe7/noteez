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
      case 'quit':
        _quit();
    }
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
}

final menubar = MenubarController();
