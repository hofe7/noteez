import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'backup/backup_service.dart';
import 'connection_engine.dart';
import 'db/database.dart';
import 'huggingface_model_search.dart';
import 'ipc.dart';
import 'link_graph.dart';
import 'markdown/import_merge.dart';
import 'markdown/markdown_portability.dart';
import 'model_manager.dart';
import 'models/sticky.dart';
import 'models/model_catalog.dart';
import 'reminder/notifier.dart';
import 'reminder/reminder_scheduler.dart';
import 'report.dart';
import 'sticky_search.dart';

const _uuid = Uuid();

/// 메인 프로세스 = 권위자. 상태 + Drift(SQLite) 영속화 소유, 스티커 창 생성/추적.
class MainController extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  final BackupService _backups = BackupService();
  final ConnectionEngine _conn = ConnectionEngine();
  final ModelManager _models = ModelManager();
  final HuggingFaceModelSearch _modelSearch = HuggingFaceModelSearch();
  final List<Sticky> stickies = [];
  final Map<String, WindowController> _windows = {};
  WindowController? _overviewWin; // 전체 보기 창(열려 있으면 변경을 push)
  WindowController? _modelWin;
  String? _overviewNotice;
  int _indexedNotes = 0;
  int _indexTotal = 0;
  int _indexGeneration = 0;

  /// 승인된 연결(지식 그래프). 인접/묶음 알고리즘은 LinkGraph 가 담당.
  final LinkGraph _graph = LinkGraph();
  final MarkdownPortability _markdown = MarkdownPortability();
  final List<NoteGroupRow> _noteGroups = [];
  final Map<String, GroupMemberRow> _groupMembers = {};

  /// 현재 콘텐츠 버전에 대해 사용자가 숨긴 추천 pair.
  final Map<String, ({String aId, String bId, String aHash, String bHash})>
  _dismissals = {};

  /// 리마인더 타이머. 발화 시 알림(best-effort) 또는 자동 소환.
  late final ReminderScheduler _reminders = ReminderScheduler(_fireReminder);
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
    await const WindowMethodChannel(
      kMainChannel,
      mode: ChannelMode.unidirectional,
    ).setMethodCallHandler(_onCall);

    _models.addListener(_pushModelState);
    await _models.initialize();
    _conn.selectModel(_models.selectedModel);

    final loaded = await _db.allActive();
    if (loaded.isEmpty) {
      // 첫 실행: 시드 저장.
      for (final s in seedStickies()) {
        await _db.upsert(s);
        stickies.add(s);
      }
    } else {
      stickies.addAll(loaded);
    }
    await _reloadNoteGroups();

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
      if (e != null) {
        _conn.seed(
          s.id,
          e.hash,
          (jsonDecode(e.vec) as List)
              .map((x) => (x as num).toDouble())
              .toList(),
        );
      }
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

  /// 리마인더 발화: 그 스티커를 desk 로 소환 + one-shot 으로 remindAt 비움.
  /// (best-effort 알림은 Phase C 에서 얹음.)
  Future<void> _fireReminder(String id) async {
    final i = stickies.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final s = stickies[i] = stickies[i].copyWith(clearRemind: true);
    await _db.upsert(s);
    // 알림 가능하면 알림(클릭 시 소환), 아니면 자동 소환 폴백(권한 불필요, 항상 동작).
    if (_notifier.granted) {
      await _notifier.show(id, '⏰ ${s.preview}', '리마인더');
    } else {
      await showOne(id, focus: false); // 폴백: 떠오르되 커서는 안 뺏음
    }
    notifyListeners();
    _pushOverview();
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
    if (_graph.neighbors(a).contains(b)) return false;
    await _db.insertLink(
      _uuid.v4(),
      a,
      b,
      DateTime.now().millisecondsSinceEpoch,
    );
    _graph.addEdge(a, b);
    return true;
  }

  Future<void> _linkIds(List<String> rawIds) async {
    final ids = rawIds.where((id) => _stickyOf(id) != null).toSet().toList();
    if (ids.length < 2) return;
    final anchor = ids.first;
    for (final id in ids.skip(1)) {
      await _linkPair(anchor, id);
    }
    _pushOverview();
  }

  Future<void> _reloadNoteGroups() async {
    _noteGroups
      ..clear()
      ..addAll(await _db.allActiveGroups());
    _groupMembers
      ..clear()
      ..addEntries(
        (await _db.allGroupMembers()).map((m) => MapEntry(m.stickyId, m)),
      );
    final liveGroupIds = _noteGroups.map((g) => g.id).toSet();
    _groupMembers.removeWhere(
      (stickyId, member) =>
          !liveGroupIds.contains(member.groupId) || _stickyOf(stickyId) == null,
    );
  }

  String _cleanGroupName(String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return '새 묶음';
    return name.length > 80 ? name.substring(0, 80).trimRight() : name;
  }

  Future<String> _createNoteGroup(
    String name,
    Iterable<String> ids, {
    String? requestedId,
    bool collapsed = false,
    int? requestedPosition,
  }) async {
    final id = requestedId?.trim().isNotEmpty == true
        ? requestedId!.trim()
        : _uuid.v4();
    final position =
        requestedPosition ??
        (_noteGroups.isEmpty
            ? 0
            : _noteGroups
                      .map((g) => g.position)
                      .reduce((a, b) => a > b ? a : b) +
                  1);
    await _db.upsertNoteGroup(
      id: id,
      name: _cleanGroupName(name),
      position: position,
      collapsed: collapsed,
    );
    await _db.assignNotesToGroup(
      id,
      ids.where((noteId) => _stickyOf(noteId) != null),
    );
    await _reloadNoteGroups();
    _pushOverview();
    return id;
  }

  Future<void> _assignNotesToGroup(String groupId, Iterable<String> ids) async {
    if (!_noteGroups.any((g) => g.id == groupId)) return;
    await _db.assignNotesToGroup(
      groupId,
      ids.where((noteId) => _stickyOf(noteId) != null),
    );
    await _reloadNoteGroups();
    _pushOverview();
  }

  Future<void> _unlinkPair(String a, String b) async {
    await _db.softDeleteLinkBetween(a, b);
    _graph.removeEdge(a, b);
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
    _pushOverview();
  }

  Future<dynamic> _onCall(MethodCall call) async {
    switch (call.method) {
      case ToMain.updateSticky:
        var s = Sticky.fromJson(
          jsonDecode(call.arguments as String) as Map<String, dynamic>,
        );
        // 리마인더는 setReminder 가 권위자. 창이 일반 업데이트로 보낸 과거 remindAt
        // (이미 발화된 것)은 무시 — 재시작 시 catch-up 재발화 방지.
        final ra = s.remindAt;
        if (ra != null && ra <= DateTime.now().millisecondsSinceEpoch) {
          s = s.copyWith(clearRemind: true);
        }
        final i = stickies.indexWhere((e) => e.id == s.id);
        if (i != -1) {
          stickies[i] = s;
        } else {
          stickies.add(s);
        }
        await _db.upsert(s);
        await _conn.index(s);
        notifyListeners();
        _pushOverview();
      case ToMain.deleteSticky:
        final id = call.arguments as String;
        stickies.removeWhere((e) => e.id == id);
        _windows.remove(id);
        _conn.remove(id);
        _graph.remove(id);
        _reminders.cancel(id);
        await _db.softDelete(id);
        await _db.deleteEmbedding(id);
        await _db.softDeleteLinksFor(id);
        await _db.deleteSuggestionDismissalsFor(id);
        await _db.deleteImportOriginsFor(id);
        await _db.deleteGroupMembershipForNote(id);
        _groupMembers.remove(id);
        _dismissals.removeWhere((_, d) => d.aId == id || d.bId == id);
        notifyListeners();
        _pushOverview();
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
        return _createNoteGroup(
          m['name'] as String? ?? '',
          ((m['ids'] as List?) ?? const []).cast<String>(),
          requestedId: m['id'] as String?,
          collapsed: m['collapsed'] as bool? ?? false,
          requestedPosition: m['position'] as int?,
        );
      case ToMain.renameNoteGroup:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        await _db.renameNoteGroup(
          m['id'] as String,
          _cleanGroupName(m['name'] as String? ?? ''),
        );
        await _reloadNoteGroups();
        _pushOverview();
      case ToMain.deleteNoteGroup:
        await _db.softDeleteNoteGroup(call.arguments as String);
        await _reloadNoteGroups();
        _pushOverview();
      case ToMain.assignNotesToGroup:
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        await _assignNotesToGroup(
          m['groupId'] as String,
          ((m['ids'] as List?) ?? const []).cast<String>(),
        );
      case ToMain.removeNotesFromGroup:
        final ids = (jsonDecode(call.arguments as String) as List)
            .cast<String>();
        await _db.removeNotesFromGroup(ids);
        await _reloadNoteGroups();
        _pushOverview();
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
      case ToMain.dismissSuggestions:
        final ids = (jsonDecode(call.arguments as String) as List)
            .cast<String>();
        await _dismissIds(ids);
      case ToMain.closeSticky:
        // 닫기(보관): 창만 닫고 데이터는 유지(open=false).
        final id = call.arguments as String;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          stickies[i] = stickies[i].copyWith(open: false);
          await _db.upsert(stickies[i]);
        }
        _windows.remove(id);
        _pushOverview();
      case ToMain.drawerSticky:
        // 전체 보기에서 '서랍에 넣기': 데이터 open=false + 실제 창 닫기 요청.
        final id = call.arguments as String;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          stickies[i] = stickies[i].copyWith(open: false);
          await _db.upsert(stickies[i]);
        }
        final wc = _windows.remove(id);
        if (wc != null) {
          try {
            await wc.invokeMethod(ToWindow.requestClose);
          } catch (_) {
            /* 이미 닫힘 등 */
          }
        }
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
          stickies[i] = stickies[i].copyWith(remindAt: at);
          await _db.upsert(stickies[i]);
          _reminders.schedule(id, at);
          notifyListeners();
          _pushOverview();
        }
      case ToMain.clearReminder:
        final id = call.arguments as String;
        _reminders.cancel(id);
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          stickies[i] = stickies[i].copyWith(clearRemind: true);
          await _db.upsert(stickies[i]);
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

  /// 승인된 연결의 연결요소(묶음) 목록. 각 멤버 {id,preview,color}, 큰 묶음 먼저.
  /// 검색창 '둘러보기' + 회고에 사용. (그래프 알고리즘은 LinkGraph, 여기선 표현 매핑만)
  List<List<Map<String, dynamic>>> clusters() => [
    for (final comp in _graph.clusters())
      [
        for (final id in comp) _nodeOf(id),
      ].whereType<Map<String, dynamic>>().toList(),
  ];

  /// 한 메모와 '같은 묶음'인 다른 메모들 (가까운=연결 많은 순). 없으면 빈 리스트.
  List<Map<String, dynamic>> sameCluster(String id) => [
    for (final cid in _graph.sameCluster(id)) _nodeOf(cid),
  ].whereType<Map<String, dynamic>>().toList();

  Future<void> addSticky() async {
    final n = stickies.length;
    final s = makeSticky(
      x: 200 + n * 26.0,
      y: 180 + n * 26.0,
      colorIndex: n % 6,
    );
    stickies.add(s);
    await _db.upsert(s);
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
    final changed = <Sticky>[];
    final bySourcePath = <String, String>{};
    final importedGroups = <String, ({String? groupId, String? groupName})>{};
    var imported = 0;
    var updated = 0;
    var skipped = 0;
    var conflicted = 0;
    for (final note in batch.notes) {
      final origin = await _db.importOrigin(note.sourceKey);
      final existing = origin == null ? null : _stickyOf(origin.stickyId);
      var updateOrigin = true;
      Sticky sticky;
      final decision = decideMarkdownImport(
        hasOrigin: origin != null,
        hasSticky: existing != null,
        sourceUnchanged: origin?.sourceHash == note.sourceHash,
        stickyUnchangedSinceImport:
            origin != null &&
            existing != null &&
            _conn.documentHash(existing) == origin.stickyHash,
      );
      if (decision == MarkdownImportDecision.skip) {
        sticky = existing!;
        skipped++;
        // 같은 원본을 다시 고른 것뿐이다. 사용자가 Noteez에서 편집했더라도
        // 최초 import 시점의 stickyHash를 유지해야 다음 원본 변경 때 덮어쓰기
        // 여부를 정확히 판정할 수 있다.
        updateOrigin = false;
      } else if (decision == MarkdownImportDecision.update) {
        sticky = existing!.copyWith(
          blocks: _importBlocks(note),
          updatedAt: note.metadata.updatedAt ?? DateTime.now(),
        );
        final index = stickies.indexWhere((s) => s.id == existing.id);
        stickies[index] = sticky;
        await _db.upsert(sticky);
        changed.add(sticky);
        updated++;
      } else if (decision == MarkdownImportDecision.preserveBoth) {
        sticky = _newImportedSticky(note);
        stickies.add(sticky);
        await _db.upsert(sticky);
        changed.add(sticky);
        imported++;
        conflicted++;
      } else {
        final externalId = note.metadata.noteezId;
        final sameId = externalId == null ? null : _stickyOf(externalId);
        if (sameId != null &&
            _conn.documentHash(sameId) ==
                _conn.documentHash(_newImportedSticky(note, id: externalId))) {
          sticky = sameId;
          skipped++;
        } else {
          sticky = _newImportedSticky(
            note,
            id: externalId != null && sameId == null ? externalId : null,
          );
          stickies.add(sticky);
          await _db.upsert(sticky);
          changed.add(sticky);
          imported++;
        }
      }
      bySourcePath[note.sourcePath] = sticky.id;
      if (note.metadata.noteezGroupId != null ||
          note.metadata.noteezGroupName != null) {
        importedGroups[sticky.id] = (
          groupId: note.metadata.noteezGroupId,
          groupName: note.metadata.noteezGroupName,
        );
      }
      if (updateOrigin) {
        await _db.upsertImportOrigin(
          sourceKey: note.sourceKey,
          stickyId: sticky.id,
          sourceHash: note.sourceHash,
          stickyHash: _conn.documentHash(sticky),
        );
      }
    }

    var linked = 0;
    for (final link in batch.links) {
      final a = bySourcePath[link.sourcePath];
      final b = bySourcePath[link.targetPath];
      if (a != null && b != null && await _linkPair(a, b)) linked++;
    }
    // 한 파일만 가져온 경우에도 [[기존 메모]] / Existing.md 링크를 복원한다.
    // 같은 제목이 둘 이상이면 모호하므로 자동 연결하지 않는다.
    final idsByTitle = <String, List<String>>{};
    for (final sticky in stickies) {
      final title = sticky.preview.trim().toLowerCase();
      if (title.isNotEmpty) (idsByTitle[title] ??= []).add(sticky.id);
    }
    for (final note in batch.notes) {
      final sourceId = bySourcePath[note.sourcePath];
      if (sourceId == null) continue;
      for (final reference in note.references) {
        final title = _markdown.referenceTitle(reference).toLowerCase();
        final candidates = idsByTitle[title];
        if (candidates?.length == 1 &&
            await _linkPair(sourceId, candidates!.single)) {
          linked++;
        }
      }
    }

    var groupsChanged = false;
    final restoredGroupIds = <String, String>{};
    for (final entry in importedGroups.entries) {
      final metadata = entry.value;
      final sourceKey = metadata.groupId?.trim().isNotEmpty == true
          ? 'id:${metadata.groupId!.trim()}'
          : 'name:${(metadata.groupName ?? '').trim().toLowerCase()}';
      var groupId = restoredGroupIds[sourceKey];
      if (groupId == null) {
        final requestedId = metadata.groupId?.trim();
        NoteGroupRow? existing;
        for (final group in _noteGroups) {
          if ((requestedId?.isNotEmpty == true && group.id == requestedId) ||
              (requestedId?.isNotEmpty != true &&
                  group.name.toLowerCase() ==
                      (metadata.groupName ?? '').trim().toLowerCase())) {
            existing = group;
            break;
          }
        }
        groupId = existing?.id;
        groupId ??= await _createNoteGroup(
          metadata.groupName ?? '가져온 묶음',
          const [],
          requestedId: requestedId,
        );
        restoredGroupIds[sourceKey] = groupId;
      }
      await _db.assignNotesToGroup(groupId, [entry.key]);
      groupsChanged = true;
    }
    if (groupsChanged) await _reloadNoteGroups();

    if (changed.isNotEmpty || linked > 0 || groupsChanged) {
      notifyListeners();
      _pushOverview();
      unawaited(_conn.warmup(changed).then((_) => _pushOverview()));
    }
    final result = (
      imported: imported,
      updated: updated,
      skipped: skipped,
      conflicted: conflicted,
      linked: linked,
      failed: batch.failedPaths.length,
    );
    _overviewNotice = _importSummary(result);
    if (batch.notes.isNotEmpty || batch.failedPaths.isNotEmpty) {
      await openOverview();
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

  List<Block> _importBlocks(ImportedMarkdownNote note) =>
      note.blocks.isEmpty ? [textBlock(note.title)] : note.blocks;

  Sticky _newImportedSticky(ImportedMarkdownNote note, {String? id}) {
    final n = stickies.length;
    final now = DateTime.now();
    return Sticky(
      id: id ?? _uuid.v4(),
      blocks: _importBlocks(note),
      colorIndex: (note.metadata.colorIndex ?? n % 6).clamp(0, 5),
      x: 200 + n * 26.0,
      y: 180 + n * 26.0,
      open: false,
      createdAt: note.metadata.createdAt ?? now,
      updatedAt: note.metadata.updatedAt ?? now,
    );
  }

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

  Future<void> shutdown() => _db.close();

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
      stickies[i] = stickies[i].copyWith(open: true);
      await _db.upsert(stickies[i]);
    }
    // 닫혀있던 창: 새로 띄움. focusOnOpen 으로 커서 포커스 여부 전달.
    await _spawn(stickies[i], focusOnOpen: focus);
    notifyListeners();
    _pushOverview();
  }

  Map<String, dynamic>? noteBrief(String id) => _nodeOf(id);

  /// 검색 결과를 두 묶음으로:
  ///  - exact: 키워드가 실제로 들어있는 메모(정확한 일치). 또는 날짜/빈쿼리 결과.
  ///  - related: 키워드는 없지만 의미상 가까운 메모(AI 관련). 노이즈 방지로 높은 바 + 소수만.
  /// 검색(키워드/날짜 + 의미 관련). 로직은 sticky_search 에 분리, 여기선 의미 점수
  /// 공급자(임베딩 엔진)만 주입.
  Future<SearchResult> search(String query) => searchStickies(
    stickies,
    query,
    DateTime.now(),
    (q) async => {for (final e in await _conn.rankByQuery(q)) e.key: e.value},
  );

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
    stickies.add(s);
    await _db.upsert(s);
    await _conn.index(s);
    // 캡처한 노트는 화면에 나타나게(보이는 게 안 보이는 것보다 낫다).
    await _spawn(s);
    notifyListeners();
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
          'updatedAt': s.updatedAt.millisecondsSinceEpoch,
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
    final groups = [
      for (final group in _noteGroups)
        {
          'id': group.id,
          'name': group.name,
          'position': group.position,
          'collapsed': group.collapsed,
          'memberIds': [
            for (final member
                in memberships[group.id] ?? const <GroupMemberRow>[])
              member.stickyId,
          ],
        },
    ];
    // 사용자가 확정한 묶음은 추천에서 제외한다. 추천은 표현용 계산 결과일 뿐
    // DB/LinkGraph를 바꾸지 않으며 다음 임베딩 갱신 때 다시 계산된다.
    final confirmedIds = {
      ..._graph.clusters().expand((c) => c),
      ..._groupMembers.keys,
    };
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

  Future<void> _spawn(Sticky s, {bool focusOnOpen = false}) async {
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
