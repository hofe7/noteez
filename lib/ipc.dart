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
  static const String getTrash = 'getTrash';
  static const String restoreTrashed = 'restoreTrashed';
  static const String permanentlyDeleteTrashed = 'permanentlyDeleteTrashed';
  static const String newSticky = 'newSticky';
  static const String openOrganization = 'openOrganization';
  static const String getOrganization = 'getOrganization';
  static const String restoreNoteMemberships = 'restoreNoteMemberships';
  static const String getConnection = 'getConnection';
  static const String linkStickies = 'linkStickies';
  static const String linkGroup = 'linkGroup';
  static const String createNoteGroup = 'createNoteGroup';
  static const String renameNoteGroup = 'renameNoteGroup';
  static const String deleteNoteGroup = 'deleteNoteGroup';
  static const String assignNotesToGroup = 'assignNotesToGroup';
  static const String removeNotesFromGroup = 'removeNotesFromGroup';
  static const String setNoteGroupCollapsed = 'setNoteGroupCollapsed';
  static const String unlinkStickies = 'unlinkStickies';
  static const String dismissSuggestions = 'dismissSuggestions';
  static const String dismissGroupSuggestion = 'dismissGroupSuggestion';
  static const String resetGroupSuggestions = 'resetGroupSuggestions';
  static const String closeSticky = 'closeSticky';
  static const String drawerSticky = 'drawerSticky';
  static const String focusSticky = 'focusSticky';
  static const String setReminder = 'setReminder';
  static const String clearReminder = 'clearReminder';
  static const String getModelState = 'getModelState';
  static const String downloadModel = 'downloadModel';
  static const String cancelModelDownload = 'cancelModelDownload';
  static const String selectModel = 'selectModel';
  static const String deleteModel = 'deleteModel';
  static const String searchModels = 'searchModels';
  static const String installSearchModel = 'installSearchModel';
  static const String openModels = 'openModels';
  static const String getBackupState = 'getBackupState';
  static const String createAutomaticBackup = 'createAutomaticBackup';
  static const String restoreBackupPath = 'restoreBackupPath';
  static const String openBackupFolder = 'openBackupFolder';
  static const String restartForRestore = 'restartForRestore';
}

/// 메인 → 개별 창 메서드명 (각 창의 기본 채널로 invoke).
abstract final class ToWindow {
  static const String requestClose = 'requestClose';
  static const String flushPendingWrites = 'flushPendingWrites';
  static const String refreshConnections = 'refreshConnections';
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

  Future<List<Map<String, dynamic>>> getTrash() async =>
      (jsonDecode(await _ch.invokeMethod(ToMain.getTrash) as String) as List)
          .cast<Map<String, dynamic>>();

  Future<void> restoreTrashed(String id) =>
      _ch.invokeMethod(ToMain.restoreTrashed, id);

  Future<void> permanentlyDeleteTrashed(String id) =>
      _ch.invokeMethod(ToMain.permanentlyDeleteTrashed, id);

  Future<void> closeSticky(String id) =>
      _ch.invokeMethod(ToMain.closeSticky, id);

  Future<void> drawerSticky(String id) =>
      _ch.invokeMethod(ToMain.drawerSticky, id);

  Future<void> focusSticky(String id) =>
      _ch.invokeMethod(ToMain.focusSticky, id);

  Future<void> newSticky() => _ch.invokeMethod(ToMain.newSticky);

  Future<void> linkStickies(String a, String b) =>
      _ch.invokeMethod(ToMain.linkStickies, jsonEncode({'a': a, 'b': b}));

  Future<void> linkGroup(List<String> ids) =>
      _ch.invokeMethod(ToMain.linkGroup, jsonEncode(ids));

  Future<String?> createNoteGroup(
    String name,
    List<String> ids, {
    String? requestedId,
    bool collapsed = false,
    int? position,
  }) async =>
      await _ch.invokeMethod(
            ToMain.createNoteGroup,
            jsonEncode({
              'name': name,
              'ids': ids,
              'id': requestedId,
              'collapsed': collapsed,
              'position': position,
            }),
          )
          as String?;

  Future<void> dismissGroupSuggestion(String noteId, String groupId) =>
      _ch.invokeMethod(
        ToMain.dismissGroupSuggestion,
        jsonEncode({'noteId': noteId, 'groupId': groupId}),
      );

  Future<void> resetGroupSuggestions(String groupId) =>
      _ch.invokeMethod(ToMain.resetGroupSuggestions, groupId);

  Future<void> renameNoteGroup(String id, String name) => _ch.invokeMethod(
    ToMain.renameNoteGroup,
    jsonEncode({'id': id, 'name': name}),
  );

  Future<void> deleteNoteGroup(String id) =>
      _ch.invokeMethod(ToMain.deleteNoteGroup, id);

  Future<void> assignNotesToGroup(String groupId, List<String> ids) =>
      _ch.invokeMethod(
        ToMain.assignNotesToGroup,
        jsonEncode({'groupId': groupId, 'ids': ids}),
      );

  Future<void> removeNotesFromGroup(List<String> ids) =>
      _ch.invokeMethod(ToMain.removeNotesFromGroup, jsonEncode(ids));

  Future<void> setNoteGroupCollapsed(String id, bool collapsed) =>
      _ch.invokeMethod(
        ToMain.setNoteGroupCollapsed,
        jsonEncode({'id': id, 'collapsed': collapsed}),
      );

  Future<void> unlinkStickies(String a, String b) =>
      _ch.invokeMethod(ToMain.unlinkStickies, jsonEncode({'a': a, 'b': b}));

  Future<void> dismissSuggestions(List<String> ids) =>
      _ch.invokeMethod(ToMain.dismissSuggestions, jsonEncode(ids));

  /// 리마인더 설정: atMillis 시각에 그 스티커를 소환(+알림). 기존 예약 대체.
  Future<void> setReminder(String id, int atMillis) => _ch.invokeMethod(
    ToMain.setReminder,
    jsonEncode({'id': id, 'at': atMillis}),
  );

  Future<void> clearReminder(String id) =>
      _ch.invokeMethod(ToMain.clearReminder, id);

  Future<Map<String, dynamic>> getModelState() async =>
      jsonDecode(await _ch.invokeMethod(ToMain.getModelState) as String)
          as Map<String, dynamic>;

  Future<void> downloadModel(String id) =>
      _ch.invokeMethod(ToMain.downloadModel, id);

  Future<void> cancelModelDownload() =>
      _ch.invokeMethod(ToMain.cancelModelDownload);

  Future<void> selectModel(String id) =>
      _ch.invokeMethod(ToMain.selectModel, id);

  Future<void> deleteModel(String id) =>
      _ch.invokeMethod(ToMain.deleteModel, id);

  Future<Map<String, dynamic>> searchModels(String query) async =>
      jsonDecode(await _ch.invokeMethod(ToMain.searchModels, query) as String)
          as Map<String, dynamic>;

  Future<void> installSearchModel(Map<String, dynamic> profile) =>
      _ch.invokeMethod(ToMain.installSearchModel, jsonEncode(profile));

  Future<void> openModels() => _ch.invokeMethod(ToMain.openModels);

  Future<Map<String, dynamic>> getBackupState() async =>
      jsonDecode(await _ch.invokeMethod(ToMain.getBackupState) as String)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> createAutomaticBackup() async =>
      jsonDecode(await _ch.invokeMethod(ToMain.createAutomaticBackup) as String)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> restoreBackupPath(String path) async =>
      jsonDecode(
            await _ch.invokeMethod(ToMain.restoreBackupPath, path) as String,
          )
          as Map<String, dynamic>;

  Future<void> openBackupFolder() => _ch.invokeMethod(ToMain.openBackupFolder);

  Future<void> restartForRestore() =>
      _ch.invokeMethod(ToMain.restartForRestore);

  Future<void> openOrganization(String id) =>
      _ch.invokeMethod(ToMain.openOrganization, id);

  Future<Map<String, dynamic>> getOrganization() async =>
      jsonDecode(await _ch.invokeMethod(ToMain.getOrganization) as String)
          as Map<String, dynamic>;

  Future<void> restoreNoteMemberships(
    Map<String, String?> memberships, {
    String? deleteGroupId,
  }) => _ch.invokeMethod(
    ToMain.restoreNoteMemberships,
    jsonEncode({'memberships': memberships, 'deleteGroupId': deleteGroupId}),
  );

  Future<ConnectionResult> getConnection(String id) async =>
      ConnectionResult.parse(await _ch.invokeMethod(ToMain.getConnection, id));
}
