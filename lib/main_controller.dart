import 'services/link_service.dart';
import 'models/link_change.dart';
import 'services/note_save_service.dart';
import 'services/group_service.dart';
import 'models/group_change.dart';
import 'models/saved_note_open_failure.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'backup/backup_service.dart';
import 'connection_engine.dart';
import 'db/database.dart';
import 'huggingface_model_search.dart';
import 'ipc.dart';
import 'link_graph.dart';
import 'services/markdown_import_service.dart';
import 'markdown/markdown_portability.dart';
import 'model_manager.dart';
import 'models/sticky.dart';
import 'models/model_catalog.dart';
import 'reminder/notifier.dart';
import 'reminder/reminder_scheduler.dart';
import 'report.dart';
import 'sticky_search.dart';

/// 메인 프로세스 = 권위자. 상태 + Drift(SQLite) 영속화 소유, 스티커 창 생성/추적.
class MainController extends ChangeNotifier {
  MainController({
    AppDatabase? database,
    ReminderScheduler? reminders,
    Future<void> Function(Sticky)? deliverReminder,
  }) : _db = database ?? AppDatabase(),
       _injectedReminders = reminders,
       _deliverReminderOverride = deliverReminder;
  final ReminderScheduler? _injectedReminders;
  final Future<void> Function(Sticky)? _deliverReminderOverride;
  final Map<String, int> _reminderRevisions = {};
  bool _closing = false;

  final AppDatabase _db;
  late final GroupService _groups = GroupService(_db);
  late final NoteSaveService _noteSaves = NoteSaveService(
    persist: _db.updateExisting,
    read: _stickyOf,
    publish: (note) {
      final index = stickies.indexWhere((s) => s.id == note.id);
      if (index < 0) return;
      stickies[index] = note;
      _queueIndex(note);
      notifyListeners();
      _pushOverview();
    },
  );
  late final BackupService _backups = BackupService(
    beforeSnapshot: flushPendingWrites,
  );
  final ConnectionEngine _conn = ConnectionEngine();
  final ModelManager _models = ModelManager();
  final HuggingFaceModelSearch _modelSearch = HuggingFaceModelSearch();
  final List<Sticky> stickies = [];
  final Map<String, WindowController> _windows = {};
  final Map<String, Future<void>> _spawning = {};
  WindowController? _overviewWin; // 전체 보기 창(열려 있으면 변경을 push)
  WindowController? _modelWin;
  WindowController? _backupWin;
  String? _overviewNotice;
  int _indexedNotes = 0;
  int _indexTotal = 0;
  int _indexGeneration = 0;
  Future<void> Function()? onRestartRequested;

  /// 승인된 연결(지식 그래프). 인접/묶음 알고리즘은 LinkGraph 가 담당.
  final LinkGraph _graph = LinkGraph();
  late final LinkService _links = LinkService(
    _db,
    publish: (a, b, linked) {
      if (linked) {
        _graph.addEdge(a, b);
      } else {
        _graph.removeEdge(a, b);
      }
    },
  );
  final MarkdownPortability _markdown = MarkdownPortability();
  final List<NoteGroupRow> _noteGroups = [];
  final Map<String, GroupMemberRow> _groupMembers = {};
  final Set<String> _groupSuggestionDismissals = {};
  String _groupDismissalKey(String note, String group) =>
      jsonEncode([note, group]);

  /// 현재 콘텐츠 버전에 대해 사용자가 숨긴 추천 pair.
  final Map<String, ({String aId, String bId, String aHash, String bHash})>
  _dismissals = {};

  /// 리마인더 타이머. 발화 시 알림(best-effort) 또는 자동 소환.
  late final ReminderScheduler _reminders =
      _injectedReminders ??
      ReminderScheduler(
        deliverDueReminder,
        onError: (error, stack) {
          debugPrint('[reminder] delivery failed; will retry: $error');
        },
      );
  final ReminderNotifier _notifier = ReminderNotifier();

  /// 검색 팔레트(메인 창)를 열 때마다 틱. 팔레트가 듣고 초기화+포커스.
  final ValueNotifier<int> searchTick = ValueNotifier<int>(0);

  /// 빠른 캡처 바를 열 때마다 틱.
  final ValueNotifier<int> captureTick = ValueNotifier<int>(0);
  final ValueNotifier<int> modelTick = ValueNotifier<int>(0);

  bool get hasSelectedModel => _models.selectedModel != null;
  bool get modelIndexing => _indexTotal > 0 && _indexedNotes < _indexTotal;
  int get indexedNotes => _indexedNotes;
  int get indexTotal => _indexTotal;

  Future<void> start() async {
    const MethodChannel('noteez/lifecycle').setMethodCallHandler((call) async {
      if (call.method == 'flushPendingWrites') {
        await flushPendingWrites();
        return true;
      }
      throw MissingPluginException();
    });
    await const WindowMethodChannel(
      kMainChannel,
      mode: ChannelMode.unidirectional,
    ).setMethodCallHandler(handleWindowCall);

    _models.addListener(_pushModelState);
    await _models.initialize();
    _conn.selectModel(_models.selectedModel);

    await _db.initializeWelcome();
    stickies.addAll(await _db.allActive());
    await _reloadNoteGroups();
    for (final dismissal in await _db.allGroupSuggestionDismissals()) {
      _groupSuggestionDismissals.add(
        _groupDismissalKey(dismissal.stickyId, dismissal.groupId),
      );
    }

    // 연결(엣지) 로드 → 창 뜨자마자 "🔗 연결" 표시.
    for (final l in await _db.allActiveLinks()) {
      _graph.addEdge(l.aId, l.bId);
    }
    for (final d in await _db.allSuggestionDismissals()) {
      _dismissals[_pairKey(d.aId, d.bId)] = (
        aId: d.aId,
        bId: d.bId,
        aHash: d.aHash,
        bHash: d.bHash,
      );
    }

    // 저장된 임베딩 로드(모델 불필요) → 캐시된 메모는 연결 즉시 표시.
    _conn.onPersist = (id, hash, vec) async {
      final modelId = _conn.modelId;
      if (modelId != null) {
        await _db.upsertEmbedding(id, modelId, hash, vec);
      }
    };
    final modelId = _conn.modelId;
    final stored = modelId == null
        ? <String, EmbeddingRow>{}
        : {
            for (final e in await _db.allEmbeddingsForModel(modelId))
              e.stickyId: e,
          };
    for (final s in stickies) {
      final e = stored[s.id];
      if (e != null) _conn.seedStored(s, e.hash, e.vec);
    }

    // 열린(책상 위) 스티커만, 동시에 생성. 닫힌 건 서랍에 — 검색/연결/그래프로 소환.
    // desktop_multi_window 엔진을 한꺼번에 만들면 macOS 채널/리사이즈가 타임아웃될
    // 수 있어 순차 생성한다. 창 수가 많아도 각 엔진 handle이 준비된 뒤 다음 창으로.
    for (final s in stickies.where((s) => s.open)) {
      await _spawn(s);
    }
    notifyListeners();

    // 알림 권한 요청(best-effort). 클릭 시 그 스티커 소환. 불가하면 자동 소환 폴백.
    await _notifier.init(showOne);

    // 리마인더 예약(창 스폰 후 — 지난 건 즉시 발화되도록 catch-up).
    for (final s in stickies) {
      if (s.remindAt != null) _reminders.schedule(s.id, s.remindAt);
    }

    // 백그라운드: 새/바뀐 메모만 임베딩(모델 lazy). 창은 ~1.8초 후 재조회해 채움.
    if (_conn.modelId != null) _beginReindex();
  }

  /// Reservation stays durable until delivery succeeds. A later edit wins.
  Future<void> deliverDueReminder(String id) async {
    final note = _stickyOf(id);
    final at = note?.remindAt;
    if (_closing ||
        note == null ||
        at == null ||
        at > DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    final revision = _reminderRevisions[id] ?? 0;
    final deliver = _deliverReminderOverride;
    if (deliver != null) {
      await deliver(note);
    } else {
      var shown = false;
      final canShow = await _notifier.canShow();
      if (_closing ||
          _stickyOf(id)?.remindAt != at ||
          (_reminderRevisions[id] ?? 0) != revision) {
        return;
      }
      if (canShow) {
        try {
          await _notifier.show(id, '⏰ ${note.preview}', '리마인더');
          shown = true;
        } catch (error) {
          debugPrint('[reminder] notification failed; opening memo: $error');
        }
      }
      if (!shown &&
          !_closing &&
          _stickyOf(id)?.remindAt == at &&
          (_reminderRevisions[id] ?? 0) == revision) {
        await showOne(id, focus: false);
      }
    }
    if (_closing) return;
    await _noteSaves.update(
      id,
      (current) =>
          current.remindAt == at && (_reminderRevisions[id] ?? 0) == revision
          ? current.copyWith(clearRemind: true)
          : current,
    );
  }

  ({String a, String b}) _orderedPair(String a, String b) =>
      a.compareTo(b) <= 0 ? (a: a, b: b) : (a: b, b: a);

  String _pairKey(String a, String b) {
    final p = _orderedPair(a, b);
    return '${p.a}|${p.b}';
  }

  Sticky? _stickyOf(String id) {
    for (final s in stickies) {
      if (s.id == id) return s;
    }
    return null;
  }

  NoteGroupRow? _noteGroupOf(String id) {
    for (final group in _noteGroups) {
      if (group.id == id) return group;
    }
    return null;
  }

  bool _isSuggestionDismissed(String a, String b) {
    final d = _dismissals[_pairKey(a, b)];
    if (d == null) return false;
    final sa = _stickyOf(d.aId);
    final sb = _stickyOf(d.bId);
    if (sa == null || sb == null) return false;
    return d.aHash == _conn.contentHash(sa) && d.bHash == _conn.contentHash(sb);
  }

  Future<bool> _linkPair(String a, String b) async {
    if (a == b || _stickyOf(a) == null || _stickyOf(b) == null) return false;
    return (await _links.set(a, b, true)).undoToken != null;
  }

  Future<void> _linkIds(List<String> rawIds) async {
    final ids = rawIds.where((id) => _stickyOf(id) != null).toSet().toList();
    if (ids.length < 2) return;
    final anchor = ids.first;
    for (final id in ids.skip(1)) {
      await _linkPair(anchor, id);
    }
    _refreshConnections();
    _pushOverview();
  }

  Future<void> _reloadNoteGroups() async {
    final snapshot = await _groups.snapshot();
    final groups = snapshot.groups;
    final members = snapshot.members;
    _noteGroups
      ..clear()
      ..addAll(groups);
    _groupMembers
      ..clear()
      ..addEntries(members.map((m) => MapEntry(m.stickyId, m)));
    final liveGroupIds = _noteGroups.map((g) => g.id).toSet();
    _groupMembers.removeWhere(
      (stickyId, member) =>
          !liveGroupIds.contains(member.groupId) || _stickyOf(stickyId) == null,
    );
    notifyListeners();
    _refreshConnections();
  }

  Future<String> _groupResult(Future<GroupChange> operation) async {
    try {
      final result = await operation;
      await _reloadNoteGroups();
      _pushOverview();
      return result.encode();
    } on GroupChangeConflict catch (error) {
      throw PlatformException(
        code: 'group_conflict',
        message: error.toString(),
      );
    }
  }

  Future<void> _unlinkPair(String a, String b) async {
    await _links.set(a, b, false);
    _refreshConnections();
    _pushOverview();
  }

  Future<void> _dismissPair(String a, String b) async {
    if (a == b) return;
    final p = _orderedPair(a, b);
    final sa = _stickyOf(p.a);
    final sb = _stickyOf(p.b);
    if (sa == null || sb == null) return;
    final value = (
      aId: p.a,
      bId: p.b,
      aHash: _conn.contentHash(sa),
      bHash: _conn.contentHash(sb),
    );
    await _db.upsertSuggestionDismissal(
      aId: value.aId,
      bId: value.bId,
      aHash: value.aHash,
      bHash: value.bHash,
    );
    _dismissals[_pairKey(a, b)] = value;
  }

  Future<void> _dismissIds(List<String> rawIds) async {
    final ids = rawIds.where((id) => _stickyOf(id) != null).toSet().toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        await _dismissPair(ids[i], ids[j]);
      }
    }
    _refreshConnections();
    _pushOverview();
  }

  /// Entry point shared by the native channel and controller integration tests.
  Future<dynamic> handleWindowCall(MethodCall call) async {
    switch (call.method) {
      case ToMain.updateSticky:
        final s = Sticky.fromJson(
          jsonDecode(call.arguments as String) as Map<String, dynamic>,
        );
        // Reminder state belongs to the main process. Merge it at commit time,
        // so an editor's older snapshot cannot cancel or revive a reminder.
        await _noteSaves.update(
          s.id,
          (current) => s.copyWith(
            remindAt: current.remindAt,
            clearRemind: current.remindAt == null,
          ),
        );
      case ToMain.deleteSticky:
        final id = call.arguments as String;
        await _db.trashNote(id);
        stickies.removeWhere((e) => e.id == id);
        _windows.remove(id);
        _conn.remove(id);
        _graph.remove(id);
        _reminders.cancel(id);
        _groupMembers.remove(id);
        _dismissals.removeWhere((_, d) => d.aId == id || d.bId == id);
        _refreshConnections();
        notifyListeners();
        _pushOverview();
      case ToMain.getTrash:
        return jsonEncode([
          for (final row in await _db.allTrashed())
            {
              'id': row.id,
              'text': (jsonDecode(row.blocksJson) as List)
                  .map((b) => Block.fromJson(b as Map<String, dynamic>).text)
                  .where((text) => text.isNotEmpty)
                  .join('\n'),
              'deletedAt': row.deletedAt,
            },
        ]);
      case ToMain.restoreTrashed:
        final restored = await _db.restoreTrashed(call.arguments as String);
        if (restored != null) {
          stickies.removeWhere((s) => s.id == restored.id);
          stickies.add(restored);
          _queueIndex(restored);
          notifyListeners();
          _pushOverview();
        }
      case ToMain.permanentlyDeleteTrashed:
        await _db.permanentlyDeleteTrashed(call.arguments as String);
      case ToMain.newSticky:
        await addSticky();
      case ToMain.getConnection:
        final sid = call.arguments as String;
        final linked = _graph.neighbors(sid);
        final currentGroupId = _groupMembers[sid]?.groupId;
        final excluded = {
          ...linked,
          if (currentGroupId != null)
            for (final member in _groupMembers.values)
              if (member.groupId == currentGroupId) member.stickyId,
        };
        final linkList = <Map<String, dynamic>>[];
        for (final lid in linked) {
          final p = _previewOf(lid);
          if (p != null) linkList.add({'id': lid, 'preview': p});
        }
        final sug = _conn.connectionFor(
          sid,
          stickies,
          exclude: excluded,
          isDismissed: _isSuggestionDismissed,
        );
        return jsonEncode({'links': linkList, 'suggestion': sug?.toJson()});
      case ToMain.openOrganization:
        final noteId = call.arguments as String;
        if (_stickyOf(noteId) == null) throw StateError('메모가 없습니다.');
        final window = await WindowController.create(
          WindowConfiguration(
            hiddenAtLaunch: true,
            arguments: jsonEncode({'kind': 'organize', 'noteId': noteId}),
          ),
        );
        await window.show();
      case ToMain.getOrganization:
        return jsonEncode({
          'notes': [
            for (final note in stickies)
              {
                'id': note.id,
                'label': note.preview,
                'text': note.blocks.map((b) => b.text).join(' '),
              },
          ],
          'edges': [
            for (final edge in _graph.uniqueEdges()) {'a': edge.a, 'b': edge.b},
          ],
          'groups': [
            for (final group in _noteGroups)
              {
                'id': group.id,
                'name': group.name,
                'memberIds': [
                  for (final member in _groupMembers.values)
                    if (member.groupId == group.id) member.stickyId,
                ],
              },
          ],
        });
      case ToMain.undoGroupChange:
        try {
          await _groups.undo(call.arguments as String);
        } on GroupChangeConflict catch (error) {
          throw PlatformException(
            code: 'group_conflict',
            message: error.toString(),
          );
        }
        await _reloadNoteGroups();
        _pushOverview();
      case ToMain.changeLink:
        final data =
            jsonDecode(call.arguments as String) as Map<String, dynamic>;
        try {
          final result = await _links.set(
            data['a'] as String,
            data['b'] as String,
            data['linked'] as bool,
          );
          _refreshConnections();
          _pushOverview();
          return result.encode();
        } on LinkChangeConflict catch (error) {
          throw PlatformException(
            code: 'link_conflict',
            message: error.toString(),
          );
        }
      case ToMain.undoLinkChange:
        try {
          await _links.undo(call.arguments as String);
        } on LinkChangeConflict catch (error) {
          throw PlatformException(
            code: 'link_conflict',
            message: error.toString(),
          );
        }
        _refreshConnections();
        _pushOverview();
      case ToMain.linkStickies:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        final a = m['a'] as String;
        final b = m['b'] as String;
        await _linkIds([a, b]);
      case ToMain.linkGroup:
        final ids = (jsonDecode(call.arguments as String) as List)
            .cast<String>();
        await _linkIds(ids);
      case ToMain.createNoteGroup:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        return _groupResult(
          _groups.create(
            m['name'] as String,
            (m['ids'] as List).cast<String>(),
          ),
        );
      case ToMain.renameNoteGroup:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        return _groupResult(
          _groups.rename(m['id'] as String, m['name'] as String),
        );
      case ToMain.deleteNoteGroup:
        return _groupResult(_groups.delete(call.arguments as String));
      case ToMain.assignNotesToGroup:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        return _groupResult(
          _groups.move(
            m['groupId'] as String,
            (m['ids'] as List).cast<String>(),
          ),
        );
      case ToMain.removeNotesFromGroup:
        return _groupResult(
          _groups.remove(
            (jsonDecode(call.arguments as String) as List).cast<String>(),
          ),
        );
      case ToMain.setNoteGroupCollapsed:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        await _db.setNoteGroupCollapsed(
          m['id'] as String,
          m['collapsed'] as bool? ?? false,
        );
        await _reloadNoteGroups();
        _pushOverview();
      case ToMain.unlinkStickies:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        await _unlinkPair(m['a'] as String, m['b'] as String);
      case ToMain.dismissGroupSuggestion:
        final data =
            jsonDecode(call.arguments as String) as Map<String, dynamic>;
        final noteId = data['noteId'] as String;
        final groupId = data['groupId'] as String;
        if (_stickyOf(noteId) == null || _noteGroupOf(groupId) == null) return;
        await _db.dismissGroupSuggestion(noteId, groupId);
        _groupSuggestionDismissals.add(_groupDismissalKey(noteId, groupId));
        _pushOverview();
      case ToMain.resetGroupSuggestions:
        final groupId = call.arguments as String;
        await _db.resetGroupSuggestions(groupId);
        _groupSuggestionDismissals.removeWhere(
          (key) => (jsonDecode(key) as List)[1] == groupId,
        );
        _pushOverview();
      case ToMain.dismissSuggestions:
        final ids = (jsonDecode(call.arguments as String) as List)
            .cast<String>();
        await _dismissIds(ids);
      case ToMain.closeSticky:
        // 닫기(보관): 창만 닫고 데이터는 유지(open=false).
        final id = call.arguments as String;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          await _noteSaves.update(id, (note) => note.copyWith(open: false));
        }
        _windows.remove(id);
        _pushOverview();
      case ToMain.drawerSticky:
        final id = call.arguments as String;
        final wc = _windows[id];
        if (wc != null) {
          // The window flushes its latest edits before closing. Do not swallow
          // failures: preserving the open window is safer than losing edits.
          await wc.invokeMethod(ToWindow.requestClose);
        }
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          await _noteSaves.update(id, (note) => note.copyWith(open: false));
        }
        _windows.remove(id);
        notifyListeners();
        _pushOverview();
      case ToMain.focusSticky:
        await showOne(call.arguments as String);
      case ToMain.setReminder:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        final id = m['id'] as String;
        final at = m['at'] as int;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          await _noteSaves.update(id, (note) => note.copyWith(remindAt: at));
          _reminderRevisions[id] = (_reminderRevisions[id] ?? 0) + 1;
          _reminders.schedule(id, at);
          notifyListeners();
          _pushOverview();
        }
      case ToMain.clearReminder:
        final id = call.arguments as String;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          await _noteSaves.update(
            id,
            (note) => note.copyWith(clearRemind: true),
          );
          _reminderRevisions[id] = (_reminderRevisions[id] ?? 0) + 1;
          _reminders.cancel(id);
          notifyListeners();
          _pushOverview();
        }
      case ToMain.getModelState:
        return jsonEncode(_modelState());
      case ToMain.downloadModel:
        if (await _models.downloadAndSelect(call.arguments as String)) {
          await _activateSelectedModel();
        }
      case ToMain.cancelModelDownload:
        _models.cancelDownload();
      case ToMain.selectModel:
        await _models.select(call.arguments as String);
        await _activateSelectedModel();
      case ToMain.deleteModel:
        final id = call.arguments as String;
        final wasSelected = _models.selectedId == id;
        await _models.remove(id);
        if (wasSelected) await _activateSelectedModel();
      case ToMain.searchModels:
        final result = await _modelSearch.search(call.arguments as String);
        return jsonEncode({
          ...result.toJson(),
          'models': [
            for (final found in result.models)
              (_knownProfile(found) ?? found).toJson(),
          ],
        });
      case ToMain.installSearchModel:
        final value = jsonDecode(call.arguments as String);
        if (value is! Map<String, dynamic>) {
          throw const FormatException('모델 프로필 형식이 다릅니다.');
        }
        final profile = EmbeddingModel.fromJson(value);
        final known = _knownProfile(profile);
        if (known == null) await _models.registerCompatibleModel(profile);
        if (await _models.downloadAndSelect((known ?? profile).id)) {
          await _activateSelectedModel();
        }
      case ToMain.openModels:
        await openModels();
      case ToMain.getBackupState:
        return jsonEncode(await _backupState());
      case ToMain.createAutomaticBackup:
        await _backups.createAutomaticBackup();
        return jsonEncode(await _backupState());
      case ToMain.restoreBackupPath:
        final result = await _backups.stageRestore(call.arguments as String);
        return jsonEncode({
          'noteCount': result.noteCount,
          'imageCount': result.imageCount,
        });
      case ToMain.openBackupFolder:
        await openBackupFolder();
      case ToMain.restartForRestore:
        final restart = onRestartRequested;
        if (restart != null) {
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 150), restart),
          );
        }
    }
    return null;
  }

  String? _previewOf(String id) {
    for (final s in stickies) {
      if (s.id == id) return s.preview;
    }
    return null;
  }

  Map<String, dynamic>? _nodeOf(String id) {
    for (final s in stickies) {
      if (s.id == id) {
        return {'id': id, 'preview': s.preview, 'color': s.colorIndex};
      }
    }
    return null;
  }

  /// Search uses the same explicit group membership as the overview.
  List<Map<String, dynamic>> sameGroup(String id) {
    final groupId = _groupMembers[id]?.groupId;
    if (groupId == null) return const [];
    final members =
        _groupMembers.values
            .where((m) => m.groupId == groupId && m.stickyId != id)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return [
      for (final member in members) _nodeOf(member.stickyId),
    ].whereType<Map<String, dynamic>>().toList();
  }

  Future<void> addSticky() async {
    final n = stickies.length;
    final s = makeSticky(
      x: 200 + n * 26.0,
      y: 180 + n * 26.0,
      colorIndex: n % 6,
    );
    await _db.upsert(s);
    stickies.add(s);
    await _spawn(s);
    notifyListeners();
  }

  Future<
    ({
      int imported,
      int updated,
      int skipped,
      int conflicted,
      int linked,
      int failed,
    })?
  >
  importMarkdownFiles() async {
    final batch = await _markdown.pickFiles();
    if (batch == null) return null;
    await _backups.createAutomaticBackup();
    return _storeMarkdownImports(batch);
  }

  Future<
    ({
      int imported,
      int updated,
      int skipped,
      int conflicted,
      int linked,
      int failed,
    })?
  >
  importMarkdownFolder() async {
    final batch = await _markdown.pickFolder();
    if (batch == null) return null;
    await _backups.createAutomaticBackup();
    return _storeMarkdownImports(batch);
  }

  Future<
    ({
      int imported,
      int updated,
      int skipped,
      int conflicted,
      int linked,
      int failed,
    })?
  >
  importNotionZip() async {
    final batch = await _markdown.pickNotionZip();
    if (batch == null) return null;
    await _backups.createAutomaticBackup();
    return _storeMarkdownImports(batch);
  }

  Future<
    ({
      int imported,
      int updated,
      int skipped,
      int conflicted,
      int linked,
      int failed,
    })
  >
  _storeMarkdownImports(MarkdownImportBatch batch) async {
    late ImportSummary result;
    try {
      result = await _noteSaves.exclusive(() async {
        final result = await MarkdownImportService(
          _db,
          documentHash: _conn.documentHash,
        ).store(batch);
        // Publish only committed state, while queued editor writes wait their turn.
        stickies
          ..clear()
          ..addAll(await _db.allActive());
        for (final edge in _graph.uniqueEdges()) {
          _graph.removeEdge(edge.a, edge.b);
        }
        for (final link in await _db.allActiveLinks()) {
          _graph.addEdge(link.aId, link.bId);
        }
        await _reloadNoteGroups();
        notifyListeners();
        _pushOverview();
        _beginReindex();
        return result;
      });
    } on MarkdownImportFailure catch (error) {
      _overviewNotice = error.toString();
      try {
        await openOverview();
      } catch (_) {
      } finally {
        _overviewNotice = null;
      }
      rethrow;
    }
    _overviewNotice = _importSummary(result);
    if (batch.failedPaths.isNotEmpty) {
      final names = batch.failedPaths
          .take(5)
          .map((path) => path.replaceAll('\\', '/').split('/').last)
          .join(', ');
      _overviewNotice =
          '$_overviewNotice\n읽지 못한 파일: $names${batch.failedPaths.length > 5 ? ' 외 ${batch.failedPaths.length - 5}개' : ''} · 원본을 확인하고 다시 가져와 주세요.';
    }
    if (batch.notes.isNotEmpty || batch.failedPaths.isNotEmpty) {
      try {
        await openOverview();
      } catch (error) {
        debugPrint('[import] committed; overview could not open: $error');
      }
    }
    _overviewNotice = null;
    return result;
  }

  String _importSummary(
    ({
      int imported,
      int updated,
      int skipped,
      int conflicted,
      int linked,
      int failed,
    })
    result,
  ) => [
    '가져오기 완료',
    if (result.imported > 0) '새 메모 ${result.imported}개',
    if (result.updated > 0) '갱신 ${result.updated}개',
    if (result.skipped > 0) '중복 건너뜀 ${result.skipped}개',
    if (result.conflicted > 0) '충돌 보존 ${result.conflicted}개',
    if (result.linked > 0) '연결 복원 ${result.linked}개',
    if (result.failed > 0) '실패 ${result.failed}개',
  ].join(' · ');

  Future<MarkdownExportResult?> exportAllMarkdown() => _markdown.exportAll(
    List<Sticky>.unmodifiable(stickies),
    connections: {
      for (final sticky in stickies)
        sticky.id: Set<String>.of(_graph.neighbors(sticky.id)),
    },
    groupsBySticky: {
      for (final member in _groupMembers.values)
        if (_noteGroupOf(member.groupId) case final group?)
          member.stickyId: NoteMarkdownGroup(id: group.id, name: group.name),
    },
  );

  Future<BackupResult?> exportBackup() => _backups.pickAndCreateBackup();

  Future<RestoreResult?> stageRestore() => _backups.pickAndStageRestore();

  Future<Map<String, dynamic>> _backupState() async => {
    'directoryPath': await _backups.automaticBackupDirectoryPath(),
    'backups': [
      for (final backup in await _backups.listAutomaticBackups())
        backup.toJson(),
    ],
  };

  Future<void> openBackupFolder() async {
    final path = await _backups.automaticBackupDirectoryPath();
    await Process.run('open', [path]);
  }

  Future<void> openBackups() async {
    final state = await _backupState();
    final existing = _backupWin;
    if (existing != null) {
      try {
        await existing.invokeMethod(ToWindow.refresh, jsonEncode(state));
        await existing.show();
        return;
      } catch (_) {
        _backupWin = null;
      }
    }
    _backupWin = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'kind': 'backups', 'state': state}),
      ),
    );
  }

  Future<void> flushPendingWrites() async {
    for (final wc in List<WindowController>.of(_windows.values)) {
      await wc.invokeMethod(ToWindow.flushPendingWrites);
    }
    await _noteSaves.flush();
  }

  Future<void> shutdown() async {
    if (_closing) return;
    await flushPendingWrites();
    _closing = true;
    _reminders.dispose();
    await _links.flush();
    await _conn.close();
    await _db.close();
  }

  /// 모든 스티커 창을 앞으로.
  Future<void> showAll() async {
    for (final wc in _windows.values) {
      await wc.show();
    }
  }

  /// 특정 스티커 창을 앞으로. 닫혀있던(서랍) 메모면 다시 열어서(spawn) 소환.
  /// [focus]=false 면 창만 떠오르고 편집 커서는 안 뺏는다(리마인더 자동 소환용 —
  /// 작업 중 방해 최소화).
  Future<void> showOne(String id, {bool focus = true}) async {
    final wc = _windows[id];
    if (wc != null) {
      await wc.show();
      if (focus) {
        try {
          await wc.invokeMethod(ToWindow.focusEditor);
        } catch (_) {
          /* 핸들러 아직 미등록 등 — 무시 */
        }
      }
      return;
    }
    final i = stickies.indexWhere((e) => e.id == id);
    if (i == -1) return;
    if (!stickies[i].open) {
      await _noteSaves.update(id, (note) => note.copyWith(open: true));
    }
    // 닫혀있던 창: 새로 띄움. focusOnOpen 으로 커서 포커스 여부 전달.
    final note = _stickyOf(id);
    if (note == null) return;
    await _spawn(note, focusOnOpen: focus);
    notifyListeners();
    _pushOverview();
  }

  Map<String, dynamic>? noteBrief(String id) => _nodeOf(id);

  /// 검색 결과를 두 묶음으로:
  ///  - exact: 키워드가 실제로 들어있는 메모(정확한 일치). 또는 날짜/빈쿼리 결과.
  ///  - related: 키워드는 없지만 의미상 가까운 메모(AI 관련). 노이즈 방지로 높은 바 + 소수만.
  /// 검색(키워드/날짜 + 의미 관련). 로직은 sticky_search 에 분리, 여기선 의미 점수
  /// 공급자(임베딩 엔진)만 주입.
  Future<SearchResult> search(String query) =>
      searchStickies(stickies, query, DateTime.now(), (q) async {
        try {
          return {for (final e in await _conn.rankByQuery(q)) e.key: e.value};
        } catch (error) {
          _models.reportRuntimeFailure(error);
          _pushModelState();
          return <String, double>{};
        }
      });

  // 메인 창(검색/캡처) 투명·프레임리스를 열 때마다 재적용. (시작 시 1회만 하면
  // 숨김 상태라 안 박혀서 불투명 검정 창이 보이는 문제가 있었음.)
  Future<void> _prepCommandWindow(Size size) async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(const Color(0x00000000));
    await windowManager.setHasShadow(false); // 그림자는 패널 자체가 그림
    await windowManager.setSize(size);
    await windowManager.center();
  }

  /// 검색 팔레트(메인 창) 표시 + 포커스.
  Future<void> openSearch() async {
    await _prepCommandWindow(const Size(596, 484));
    searchTick.value++;
    await windowManager.show();
    await windowManager.focus();
  }

  /// 빠른 캡처 바(메인 창) 표시 + 포커스.
  Future<void> openCapture() async {
    await _prepCommandWindow(const Size(596, 168));
    captureTick.value++;
    await windowManager.show();
    await windowManager.focus();
  }

  /// 텍스트 한 줄을 즉시 스티커로 (빠른 캡처). "- " 로 시작하면 todo.
  Future<void> addStickyWithText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final n = stickies.length;
    String? todoText;
    if (t.startsWith('[] ')) {
      todoText = t.substring(3);
    } else if (t.startsWith('[ ] ')) {
      todoText = t.substring(4);
    }
    final block = todoText != null ? todoBlock(todoText) : textBlock(t);
    final s = makeSticky(
      x: 200 + n * 26.0,
      y: 180 + n * 26.0,
      colorIndex: n % 6,
      blocks: [block],
    );
    await _db.upsert(s);
    stickies.add(s);
    _queueIndex(s);
    notifyListeners();
    _pushOverview();
    try {
      await _spawn(s);
    } catch (_) {
      throw SavedNoteOpenFailure(s.id);
    }
  }

  /// 전체 보기 데이터(메모+연결). 열 때와 갱신 push 에 공용.
  Map<String, dynamic> _overviewData() {
    final notes = [
      for (final s in stickies)
        {
          'id': s.id,
          'label': s.preview,
          'color': s.colorIndex,
          'open': s.open,
          'updatedAt': s.contentUpdatedAt.millisecondsSinceEpoch,
          'createdAt': s.createdAt.millisecondsSinceEpoch,
        },
    ];
    final edges = [
      for (final e in _graph.uniqueEdges()) {'a': e.a, 'b': e.b},
    ];
    final memberships = <String, List<GroupMemberRow>>{};
    for (final member in _groupMembers.values) {
      (memberships[member.groupId] ??= []).add(member);
    }
    for (final members in memberships.values) {
      members.sort((a, b) => a.position.compareTo(b.position));
    }
    final additions = _conn.groupSuggestions(
      stickies,
      {
        for (final group in _noteGroups)
          group.id: [
            for (final member in memberships[group.id] ?? <GroupMemberRow>[])
              member.stickyId,
          ],
      },
      isDismissed: (note, group) =>
          _groupSuggestionDismissals.contains(_groupDismissalKey(note, group)),
      isPairDismissed: _isSuggestionDismissed,
    );
    final groups = [
      for (final group in _noteGroups)
        {
          'id': group.id,
          'name': group.name,
          'position': group.position,
          'collapsed': group.collapsed,
          'suggestions': [
            for (final addition in additions)
              if (addition.groupId == group.id) addition.toJson(),
          ],
          'memberIds': [
            for (final member
                in memberships[group.id] ?? const <GroupMemberRow>[])
              member.stickyId,
          ],
        },
    ];
    // 사용자가 확정한 묶음은 추천에서 제외한다. 추천은 표현용 계산 결과일 뿐
    // DB/LinkGraph를 바꾸지 않으며 다음 임베딩 갱신 때 다시 계산된다.
    // Reference links do not assign notes to a group or exclude group suggestions.
    final confirmedIds = _groupMembers.keys.toSet();
    final suggestedGroups = [
      for (final c in _conn.suggestedClusters(
        stickies,
        exclude: confirmedIds,
        isDismissed: _isSuggestionDismissed,
      ))
        {
          'ids': c.ids,
          'score': c.score,
          'reasons': c.reasons,
          if (c.title != null) 'title': c.title,
        },
    ];
    return {
      'notes': notes,
      'edges': edges,
      'referenceSuggestions': _conn.referenceSuggestions(
        stickies,
        isLinked: (a, b) => _graph.neighbors(a).contains(b),
        isDismissed: _isSuggestionDismissed,
        memberships: {
          for (final m in _groupMembers.values) m.stickyId: m.groupId,
        },
      ),
      'groups': groups,
      'suggestedGroups': suggestedGroups,
      'modelReady': hasSelectedModel,
      'modelIndexed': _indexedNotes,
      'modelIndexTotal': _indexTotal,
      if (_overviewNotice != null) 'notice': _overviewNotice,
    };
  }

  /// 전체 보기 창: 모든 메모(열림+서랍)를 묶음 + 그 외로 정리해 한눈에.
  Future<void> openOverview() async {
    final existing = _overviewWin;
    if (existing != null) {
      try {
        await existing.invokeMethod(
          ToWindow.refresh,
          jsonEncode(_overviewData()),
        );
        await existing.show();
        return;
      } catch (_) {
        _overviewWin = null;
      }
    }
    final wc = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'kind': 'overview', ..._overviewData()}),
      ),
    );
    _overviewWin = wc;
  }

  Map<String, dynamic> _modelState() =>
      _models.toJson(indexed: _indexedNotes, indexTotal: _indexTotal);

  EmbeddingModel? _knownProfile(EmbeddingModel candidate) {
    for (final profile in _models.catalog) {
      if (profile.repository == candidate.repository &&
          profile.revision == candidate.revision) {
        return profile;
      }
    }
    return null;
  }

  Future<void> openModels() async {
    final existing = _modelWin;
    if (existing != null) {
      try {
        await existing.invokeMethod(
          ToWindow.refresh,
          jsonEncode(_modelState()),
        );
        await existing.show();
        return;
      } catch (_) {
        _modelWin = null;
      }
    }
    _modelWin = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'kind': 'models', 'state': _modelState()}),
      ),
    );
  }

  Future<void> _activateSelectedModel() async {
    _indexGeneration++;
    _conn.selectModel(_models.selectedModel);
    await _db.deleteAllEmbeddings();
    _indexedNotes = 0;
    _indexTotal = _conn.modelId == null ? 0 : stickies.length;
    _pushModelState();
    _pushOverview();
    if (_conn.modelId != null) _beginReindex();
  }

  void _refreshConnections() {
    for (final window in _windows.values) {
      unawaited(
        window
            .invokeMethod(ToWindow.refreshConnections)
            .then<void>((_) {})
            .catchError((Object _) {}),
      );
    }
  }

  void _queueIndex(Sticky note) {
    unawaited(
      _conn
          .index(note)
          .then((_) {
            _pushOverview();
            _refreshConnections();
          })
          .catchError((Object error) {
            _models.reportRuntimeFailure(error);
            _pushModelState();
          }),
    );
  }

  void _beginReindex() {
    final modelId = _conn.modelId;
    if (modelId == null) return;
    final generation = ++_indexGeneration;
    final snapshot = List<Sticky>.of(stickies);
    _indexedNotes = 0;
    _indexTotal = snapshot.length;
    _pushModelState();
    unawaited(
      _conn
          .warmup(
            snapshot,
            onProgress: (completed, total) {
              if (generation != _indexGeneration || _conn.modelId != modelId) {
                return;
              }
              _indexedNotes = completed;
              _indexTotal = total;
              _pushModelState();
            },
          )
          .then((_) {
            if (generation == _indexGeneration) {
              _refreshConnections();
              _pushOverview();
              _pushModelState();
            }
          })
          .catchError((Object error) {
            if (generation == _indexGeneration && _conn.modelId == modelId) {
              _models.reportRuntimeFailure(error);
              _pushModelState();
              _pushOverview();
            }
          }),
    );
  }

  void _pushModelState() {
    modelTick.value++;
    final wc = _modelWin;
    if (wc == null) return;
    wc.invokeMethod(ToWindow.refresh, jsonEncode(_modelState())).catchError((
      _,
    ) {
      _modelWin = null;
      return null;
    });
  }

  /// 상태 변화 시 열려있는 전체 보기 창에 최신 데이터 push (껐다 켤 필요 없게).
  void _pushOverview() {
    final wc = _overviewWin;
    if (wc == null) return;
    wc.invokeMethod(ToWindow.refresh, jsonEncode(_overviewData())).catchError((
      _,
    ) {
      _overviewWin = null; // 창이 닫혔으면 추적 해제
      return null;
    });
  }

  /// "내가 한 일" 보고 창 열기 (로컬 집계).
  Future<void> openReport() async {
    final data = buildReport(stickies, DateTime.now());
    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'kind': 'report', 'data': data.toJson()}),
      ),
    );
  }

  Future<void> _spawn(Sticky s, {bool focusOnOpen = false}) {
    final pending = _spawning[s.id];
    if (pending != null) return pending;
    if (_windows.containsKey(s.id)) return Future.value();
    final operation = _createStickyWindow(s, focusOnOpen: focusOnOpen);
    _spawning[s.id] = operation;
    return operation.whenComplete(() => _spawning.remove(s.id));
  }

  Future<void> _createStickyWindow(
    Sticky s, {
    required bool focusOnOpen,
  }) async {
    final args = focusOnOpen
        ? jsonEncode({...s.toJson(), 'focusOnOpen': true})
        : jsonEncode(s.toJson());
    final wc = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: args),
    );
    _windows[s.id] = wc;
  }
}

final mainController = MainController();
