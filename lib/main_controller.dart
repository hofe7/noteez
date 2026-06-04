import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'connection_engine.dart';
import 'date_query.dart';
import 'db/database.dart';
import 'ipc.dart';
import 'models/sticky.dart';
import 'report.dart';

const _uuid = Uuid();

/// 메인 프로세스 = 권위자. 상태 + Drift(SQLite) 영속화 소유, 스티커 창 생성/추적.
class MainController extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  final ConnectionEngine _conn = ConnectionEngine();
  final List<Sticky> stickies = [];
  final Map<String, WindowController> _windows = {};
  WindowController? _overviewWin; // 전체 보기 창(열려 있으면 변경을 push)

  /// 승인된 연결(양방향 인접). stickyId → 연결된 stickyId 집합. 지식 그래프.
  final Map<String, Set<String>> _links = {};

  /// 검색 팔레트(메인 창)를 열 때마다 틱. 팔레트가 듣고 초기화+포커스.
  final ValueNotifier<int> searchTick = ValueNotifier<int>(0);

  /// 빠른 캡처 바를 열 때마다 틱.
  final ValueNotifier<int> captureTick = ValueNotifier<int>(0);

  Future<void> start() async {
    await const WindowMethodChannel(kMainChannel,
            mode: ChannelMode.unidirectional)
        .setMethodCallHandler(_onCall);

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

    // 연결(엣지) 로드 → 창 뜨자마자 "🔗 연결" 표시.
    for (final l in await _db.allActiveLinks()) {
      _addLinkMem(l.aId, l.bId);
    }

    // 저장된 임베딩 로드(모델 불필요) → 캐시된 메모는 연결 즉시 표시.
    _conn.onPersist = (id, hash, vec) => _db.upsertEmbedding(id, hash, vec);
    final stored = {for (final e in await _db.allEmbeddings()) e.stickyId: e};
    for (final s in stickies) {
      final e = stored[s.id];
      if (e != null) {
        _conn.seed(
            s.id,
            e.hash,
            (jsonDecode(e.vec) as List)
                .map((x) => (x as num).toDouble())
                .toList());
      }
    }

    // 열린(책상 위) 스티커만, 동시에 생성. 닫힌 건 서랍에 — 검색/연결/그래프로 소환.
    await Future.wait(stickies.where((s) => s.open).map(_spawn));
    notifyListeners();

    // 백그라운드: 새/바뀐 메모만 임베딩(모델 lazy). 창은 ~1.8초 후 재조회해 채움.
    unawaited(_conn.warmup(List.of(stickies)));
  }

  Future<dynamic> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'updateSticky':
        final s = Sticky.fromJson(
            jsonDecode(call.arguments as String) as Map<String, dynamic>);
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
      case 'deleteSticky':
        final id = call.arguments as String;
        stickies.removeWhere((e) => e.id == id);
        _windows.remove(id);
        _conn.remove(id);
        _links.remove(id);
        for (final set in _links.values) {
          set.remove(id);
        }
        await _db.softDelete(id);
        notifyListeners();
        _pushOverview();
      case 'newSticky':
        await addSticky();
      case 'getConnection':
        final sid = call.arguments as String;
        final linked = _links[sid] ?? <String>{};
        final linkList = <Map<String, dynamic>>[];
        for (final lid in linked) {
          final p = _previewOf(lid);
          if (p != null) linkList.add({'id': lid, 'preview': p});
        }
        final sug = _conn.connectionFor(sid, stickies, exclude: linked);
        return jsonEncode({'links': linkList, 'suggestion': sug?.toJson()});
      case 'linkStickies':
        final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        final a = m['a'] as String;
        final b = m['b'] as String;
        await _db.insertLink(
            _uuid.v4(), a, b, DateTime.now().millisecondsSinceEpoch);
        _addLinkMem(a, b);
        _pushOverview();
      case 'closeSticky':
        // 닫기(보관): 창만 닫고 데이터는 유지(open=false).
        final id = call.arguments as String;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          stickies[i] = stickies[i].copyWith(open: false);
          await _db.upsert(stickies[i]);
        }
        _windows.remove(id);
        _pushOverview();
      case 'drawerSticky':
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
            await wc.invokeMethod('requestClose');
          } catch (_) {/* 이미 닫힘 등 */}
        }
        notifyListeners();
        _pushOverview();
      case 'focusSticky':
        await showOne(call.arguments as String);
    }
    return null;
  }

  void _addLinkMem(String a, String b) {
    (_links[a] ??= <String>{}).add(b);
    (_links[b] ??= <String>{}).add(a);
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
  /// 검색창 '둘러보기' + 회고에 사용.
  List<List<Map<String, dynamic>>> clusters() {
    final seen = <String>{};
    final out = <List<Map<String, dynamic>>>[];
    for (final start in _links.keys) {
      if (seen.contains(start)) continue;
      if (_links[start]?.isEmpty ?? true) continue;
      final comp = <String>[];
      final q = <String>[start];
      seen.add(start);
      while (q.isNotEmpty) {
        final u = q.removeLast();
        comp.add(u);
        for (final v in _links[u] ?? const <String>{}) {
          if (seen.add(v)) q.add(v);
        }
      }
      comp.sort(
          (a, b) => (_links[b]?.length ?? 0).compareTo(_links[a]?.length ?? 0));
      final members = [for (final id in comp) _nodeOf(id)]
          .whereType<Map<String, dynamic>>()
          .toList();
      if (members.length >= 2) out.add(members);
    }
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  /// 한 메모와 '같은 묶음'인 다른 메모들 (가까운=연결 많은 순). 없으면 빈 리스트.
  List<Map<String, dynamic>> sameCluster(String id) {
    if (!_links.containsKey(id)) return const [];
    final seen = <String>{id};
    final q = <String>[id];
    final comp = <String>[];
    while (q.isNotEmpty) {
      final u = q.removeLast();
      for (final v in _links[u] ?? const <String>{}) {
        if (seen.add(v)) {
          q.add(v);
          comp.add(v);
        }
      }
    }
    comp.sort(
        (a, b) => (_links[b]?.length ?? 0).compareTo(_links[a]?.length ?? 0));
    return [for (final cid in comp) _nodeOf(cid)]
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> addSticky() async {
    final n = stickies.length;
    final s = makeSticky(x: 200 + n * 26.0, y: 180 + n * 26.0, colorIndex: n % 6);
    stickies.add(s);
    await _db.upsert(s);
    await _spawn(s);
    notifyListeners();
  }

  /// 모든 스티커 창을 앞으로.
  Future<void> showAll() async {
    for (final wc in _windows.values) {
      await wc.show();
    }
  }

  /// 특정 스티커 창을 앞으로. 닫혀있던(서랍) 메모면 다시 열어서(spawn) 소환.
  Future<void> showOne(String id) async {
    final wc = _windows[id];
    if (wc != null) {
      await wc.show();
      // 이미 열린 창: 바로 편집할 수 있게 마지막 줄에 커서.
      try {
        await wc.invokeMethod('focusEditor');
      } catch (_) {/* 핸들러 아직 미등록 등 — 무시 */}
      return;
    }
    final i = stickies.indexWhere((e) => e.id == id);
    if (i == -1) return;
    if (!stickies[i].open) {
      stickies[i] = stickies[i].copyWith(open: true);
      await _db.upsert(stickies[i]);
    }
    // 닫혀있던 창: 새로 띄우면서 포커스 플래그 전달(핸들러 등록 타이밍 회피).
    await _spawn(stickies[i], focusOnOpen: true);
    notifyListeners();
    _pushOverview();
  }

  Map<String, dynamic>? noteBrief(String id) => _nodeOf(id);

  /// 검색 결과를 두 묶음으로:
  ///  - exact: 키워드가 실제로 들어있는 메모(정확한 일치). 또는 날짜/빈쿼리 결과.
  ///  - related: 키워드는 없지만 의미상 가까운 메모(AI 관련). 노이즈 방지로 높은 바 + 소수만.
  Future<({List<Sticky> exact, List<Sticky> related})> search(
      String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      final recent = [...stickies]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return (exact: recent, related: const <Sticky>[]);
    }

    // 날짜 질의면 작성·수정일로 필터(전부 정확 묶음).
    final range = parseDateQuery(q, DateTime.now());
    if (range != null) {
      final hits = stickies
          .where((s) =>
              range.contains(s.createdAt) || range.contains(s.updatedAt))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return (exact: hits, related: const <Sticky>[]);
    }

    // 키워드 일치는 띄어쓰기·대소문자 무시 ("구조개선"="구조 개선", "redis"="Redis").
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final nq = norm(q);
    bool kw(Sticky s) => s.blocks.any((b) => norm(b.text).contains(nq));

    // 정확 일치(키워드 포함) — 최근순.
    final exact = stickies.where(kw).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final exactIds = {for (final s in exact) s.id};

    // 의미상 관련 — 키워드엔 없지만 임베딩 점수 높은 것 (음차 "레디스"→Redis 등).
    // 정확 일치가 있으면 엄격(보너스만), 없으면 관대(의미검색이 곧 답) → 빈 결과 방지.
    final sem = <String, double>{
      for (final e in await _conn.rankByQuery(q)) e.key: e.value,
    };
    final double relatedBar = exact.isEmpty ? 0.80 : 0.88;
    final int relatedMax = exact.isEmpty ? 6 : 4;
    final related = <Sticky>[];
    final cands = stickies
        .where((s) => !exactIds.contains(s.id))
        .map((s) => MapEntry(s, sem[s.id] ?? 0.0))
        .where((e) => e.value >= relatedBar)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in cands) {
      related.add(e.key);
      if (related.length >= relatedMax) break;
    }
    return (exact: exact, related: related);
  }

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
    final seen = <String>{};
    final edges = <Map<String, String>>[];
    _links.forEach((a, set) {
      for (final b in set) {
        final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
        if (seen.add(key)) edges.add({'a': a, 'b': b});
      }
    });
    return {'notes': notes, 'edges': edges};
  }

  /// 전체 보기 창: 모든 메모(열림+서랍)를 묶음 + 그 외로 정리해 한눈에.
  Future<void> openOverview() async {
    final wc = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'kind': 'overview', ..._overviewData()}),
      ),
    );
    _overviewWin = wc;
  }

  /// 상태 변화 시 열려있는 전체 보기 창에 최신 데이터 push (껐다 켤 필요 없게).
  void _pushOverview() {
    final wc = _overviewWin;
    if (wc == null) return;
    wc.invokeMethod('refresh', jsonEncode(_overviewData())).catchError((_) {
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
