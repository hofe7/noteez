import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'connection_engine.dart';
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
      case 'closeSticky':
        // 닫기(보관): 창만 닫고 데이터는 유지(open=false).
        final id = call.arguments as String;
        final i = stickies.indexWhere((e) => e.id == id);
        if (i != -1) {
          stickies[i] = stickies[i].copyWith(open: false);
          await _db.upsert(stickies[i]);
        }
        _windows.remove(id);
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
      return;
    }
    final i = stickies.indexWhere((e) => e.id == id);
    if (i == -1) return;
    if (!stickies[i].open) {
      stickies[i] = stickies[i].copyWith(open: true);
      await _db.upsert(stickies[i]);
    }
    await _spawn(stickies[i]);
  }

  /// 검색: 빈 쿼리=최근순. 모델 있으면 의미검색+키워드 부스트, 없으면 키워드만.
  Future<List<Sticky>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return [...stickies]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final lq = q.toLowerCase();
    bool kw(Sticky s) => s.blocks.any((b) => b.text.toLowerCase().contains(lq));

    // rankByQuery 가 모델 lazy 로드(첫 검색 시). 모델 없으면 [] → 키워드만.
    final sem = <String, double>{
      for (final e in await _conn.rankByQuery(q)) e.key: e.value,
    };
    final scored = stickies
        .map((s) => MapEntry(s, (sem[s.id] ?? 0.0) + (kw(s) ? 0.12 : 0.0)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const floor = 0.80; // 의미 유사도 하한 (튜닝 대상). 키워드 일치는 무조건 포함.
    final res = <Sticky>[];
    for (final e in scored) {
      if (e.value >= floor || kw(e.key)) res.add(e.key);
      if (res.length >= 20) break;
    }
    return res;
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
    await _prepCommandWindow(const Size(560, 440));
    searchTick.value++;
    await windowManager.show();
    await windowManager.focus();
  }

  /// 빠른 캡처 바(메인 창) 표시 + 포커스.
  Future<void> openCapture() async {
    await _prepCommandWindow(const Size(560, 128));
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

  /// 지식 그래프 창 열기 (승인된 연결로 구성). 연결된 메모만 표시.
  Future<void> openGraph() async {
    final linkedIds = <String>{};
    _links.forEach((a, set) {
      if (set.isNotEmpty) {
        linkedIds.add(a);
        linkedIds.addAll(set);
      }
    });
    final nodes = [
      for (final s in stickies)
        if (linkedIds.contains(s.id))
          {'id': s.id, 'label': s.preview, 'color': s.colorIndex},
    ];
    final seen = <String>{};
    final edges = <Map<String, String>>[];
    _links.forEach((a, set) {
      for (final b in set) {
        final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
        if (seen.add(key)) edges.add({'a': a, 'b': b});
      }
    });
    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments:
            jsonEncode({'kind': 'graph', 'nodes': nodes, 'edges': edges}),
      ),
    );
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

  Future<void> _spawn(Sticky s, {bool startHidden = false}) async {
    final args = startHidden
        ? jsonEncode({...s.toJson(), 'startHidden': true})
        : jsonEncode(s.toJson());
    final wc = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: args),
    );
    _windows[s.id] = wc;
  }
}

final mainController = MainController();
