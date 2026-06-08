import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'models/sticky.dart';

/// 스티커/보조 창 → 메인(권위자) 단방향 IPC 채널 이름.
/// unidirectional: 메인 엔진만 핸들러 등록, 모든 창이 invoke.
const String kMainChannel = 'noteez/main';

/// 창 → 메인 메서드명. 송신측(창)과 수신측(MainController._onCall)이 **같은 상수**를
/// 공유 → 매직스트링 오타/드리프트를 컴파일러가 잡는다.
abstract final class ToMain {
  static const String updateSticky = 'updateSticky';
  static const String deleteSticky = 'deleteSticky';
  static const String newSticky = 'newSticky';
  static const String getConnection = 'getConnection';
  static const String linkStickies = 'linkStickies';
  static const String closeSticky = 'closeSticky';
  static const String drawerSticky = 'drawerSticky';
  static const String focusSticky = 'focusSticky';
}

/// 메인 → 개별 창 메서드명 (각 창의 기본 채널로 invoke).
abstract final class ToWindow {
  static const String requestClose = 'requestClose';
  static const String focusEditor = 'focusEditor';
  static const String refresh = 'refresh';
}

/// getConnection 응답: 승인된 링크 미리보기 목록 + (있으면) 제안 1개.
/// links/suggestion 은 UI가 그대로 쓰는 맵 형태를 유지(점진적 타입화).
class ConnectionResult {
  const ConnectionResult(this.links, this.suggestion);
  final List<Map<String, dynamic>> links;
  final Map<String, dynamic>? suggestion;

  static const ConnectionResult empty = ConnectionResult([], null);

  /// IPC 응답(JSON 문자열 또는 null)을 파싱. 형식이 아니면 empty.
  static ConnectionResult parse(Object? raw) {
    if (raw is! String) return empty;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return ConnectionResult(
      (m['links'] as List).cast<Map<String, dynamic>>(),
      m['suggestion'] as Map<String, dynamic>?,
    );
  }
}

/// 창에서 메인으로 보내는 **타입 안전 호출 묶음**.
/// 매직스트링 + 수동 jsonEncode 를 이 한 곳에 가둔다 — 호출부는 의미만 표현.
class MainChannel {
  const MainChannel._(this._ch);
  final WindowMethodChannel _ch;

  static const MainChannel instance = MainChannel._(
    WindowMethodChannel(kMainChannel, mode: ChannelMode.unidirectional),
  );

  Future<void> updateSticky(Sticky s) =>
      _ch.invokeMethod(ToMain.updateSticky, jsonEncode(s.toJson()));

  Future<void> deleteSticky(String id) =>
      _ch.invokeMethod(ToMain.deleteSticky, id);

  Future<void> closeSticky(String id) =>
      _ch.invokeMethod(ToMain.closeSticky, id);

  Future<void> drawerSticky(String id) =>
      _ch.invokeMethod(ToMain.drawerSticky, id);

  Future<void> focusSticky(String id) =>
      _ch.invokeMethod(ToMain.focusSticky, id);

  Future<void> newSticky() => _ch.invokeMethod(ToMain.newSticky);

  Future<void> linkStickies(String a, String b) =>
      _ch.invokeMethod(ToMain.linkStickies, jsonEncode({'a': a, 'b': b}));

  Future<ConnectionResult> getConnection(String id) async =>
      ConnectionResult.parse(await _ch.invokeMethod(ToMain.getConnection, id));
}
