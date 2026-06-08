import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../date_util.dart';
import '../ipc.dart';
import '../link_graph.dart';
import '../sticky_palette.dart';

/// 전체 보기: 라이브러리 창. 모든 메모(열림 + 서랍)를 묶음 + 그 외로 정리하고
/// 필터/정렬/상태로 추려서 본다. 검색 팔레트가 '빠른 찾기'라면 이건 '둘러보기·정리'.
class OverviewWindowApp extends StatelessWidget {
  final List<Map<String, dynamic>> notes; // {id,label,color,open,updatedAt,createdAt}
  final List<Map<String, dynamic>> edges; // {a,b}
  const OverviewWindowApp(
      {super.key, required this.notes, required this.edges});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '전체 보기',
      theme: noteezTheme(),
      home: OverviewWindow(notes: notes, edges: edges),
    );
  }
}

enum _Status { all, open, drawer }

enum _Sort { recent, created, name }

class OverviewWindow extends StatefulWidget {
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> edges;
  const OverviewWindow({super.key, required this.notes, required this.edges});

  @override
  State<OverviewWindow> createState() => _OverviewWindowState();
}

class _OverviewWindowState extends State<OverviewWindow> {
  static const _main = MainChannel.instance;
  static const Color _accent = AppColors.accent; // 시그니처 허니 앰버

  final DateTime _now = DateTime.now();
  String _filter = '';
  _Status _status = _Status.all;
  _Sort _sort = _Sort.recent;

  // 메인이 push 하는 최신 데이터로 갱신 (창 껐다 켤 필요 없게).
  late List<Map<String, dynamic>> _notes = widget.notes;
  late List<Map<String, dynamic>> _edges = widget.edges;

  @override
  void initState() {
    super.initState();
    WindowController.fromCurrentEngine().then((c) {
      c.setWindowMethodHandler((call) async {
        if (call.method == ToWindow.refresh && mounted) {
          final m = jsonDecode(call.arguments as String) as Map<String, dynamic>;
          setState(() {
            _notes = (m['notes'] as List).cast<Map<String, dynamic>>();
            _edges = (m['edges'] as List).cast<Map<String, dynamic>>();
          });
        }
        return null;
      });
    });
  }

  Future<void> _open(String id) => _main.focusSticky(id);
  Future<void> _drawer(String id) => _main.drawerSticky(id);

  bool _matches(Map<String, dynamic> n) {
    final t = _filter.trim().toLowerCase();
    final okText =
        t.isEmpty || (n['label'] as String).toLowerCase().contains(t);
    final okStatus = switch (_status) {
      _Status.all => true,
      _Status.open => n['open'] == true,
      _Status.drawer => n['open'] != true,
    };
    return okText && okStatus;
  }

  int _cmp(Map<String, dynamic> a, Map<String, dynamic> b) => switch (_sort) {
        _Sort.recent =>
          (b['updatedAt'] as int).compareTo(a['updatedAt'] as int),
        _Sort.created =>
          (b['createdAt'] as int).compareTo(a['createdAt'] as int),
        _Sort.name => (a['label'] as String).compareTo(b['label'] as String),
      };

  // 묶음(연결요소) + 묶인 id 집합. 그래프 알고리즘은 LinkGraph(순수, 단위테스트됨)
  // 재사용 — 별 isolate라 edges 만 받지만 LinkGraph 는 의존성이 없어 그대로 쓴다.
  ({List<List<Map<String, dynamic>>> clusters, Set<String> grouped})
      _grouped() {
    final byId = {for (final n in _notes) n['id'] as String: n};
    final graph = LinkGraph();
    for (final e in _edges) {
      graph.addEdge(e['a'] as String, e['b'] as String);
    }
    final clusters = <List<Map<String, dynamic>>>[];
    final grouped = <String>{};
    for (final comp in graph.clusters()) {
      // 삭제된(목록에 없는) id 제거 후 2 미만이면 묶음 아님.
      final members = [for (final id in comp) byId[id]]
          .whereType<Map<String, dynamic>>()
          .toList();
      if (members.length < 2) continue;
      grouped.addAll(members.map((m) => m['id'] as String));
      clusters.add(members);
    }
    // 필터로 크기가 바뀔 수 있어 표시 기준(노드 수)으로 재정렬.
    clusters.sort((a, b) => b.length.compareTo(a.length));
    return (clusters: clusters, grouped: grouped);
  }

  @override
  Widget build(BuildContext context) {
    final g = _grouped();
    // 필터/정렬 적용.
    final visibleClusters = [
      for (final c in g.clusters)
        if (c.where(_matches).toList() case final m when m.isNotEmpty)
          m..sort(_cmp),
    ];
    final ungrouped = _notes
        .where((n) => !g.grouped.contains(n['id']) && _matches(n))
        .toList()
      ..sort(_cmp);
    final shown = visibleClusters.fold<int>(0, (s, c) => s + c.length) +
        ungrouped.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(g.clusters.length),
            _controls(),
            const Divider(height: 1, color: AppColors.hair),
            Expanded(
              child: (shown == 0)
                  ? _empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        for (final c in visibleClusters) ...[
                          _clusterCard(c),
                          const SizedBox(height: 14),
                        ],
                        if (ungrouped.isNotEmpty) _ungroupedSection(ungrouped),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(int clusterCount) {
    final total = _notes.length;
    final drawer = _notes.where((n) => n['open'] != true).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('전체 보기',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.ink)),
          const SizedBox(height: 3),
          Text('메모 $total개 · 묶음 $clusterCount개 · 서랍 $drawer개',
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink3)),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 18, 10),
      child: Column(
        children: [
          Row(
            children: [
              // 필터 입력
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x07000000),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0x0F000000)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16, color: Colors.black38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _filter = v),
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '메모 거르기…',
                            hintStyle: TextStyle(color: Colors.black26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 정렬
              _sortMenu(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusChip('전체', _Status.all),
              const SizedBox(width: 7),
              _statusChip('열림', _Status.open),
              const SizedBox(width: 7),
              _statusChip('서랍', _Status.drawer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortMenu() {
    String label(_Sort s) => switch (s) {
          _Sort.recent => '최근 수정',
          _Sort.created => '만든 날짜',
          _Sort.name => '이름',
        };
    return PopupMenuButton<_Sort>(
      initialValue: _sort,
      onSelected: (s) => setState(() => _sort = s),
      tooltip: '정렬',
      itemBuilder: (_) => [
        for (final s in _Sort.values)
          PopupMenuItem(value: s, child: Text(label(s))),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x07000000),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0x0F000000)),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_vert_rounded,
                size: 16, color: Colors.black45),
            const SizedBox(width: 5),
            Text(label(_sort),
                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, _Status s) {
    final on = _status == s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _status = s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? _accent.withValues(alpha: 0.16) : const Color(0x07000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? _accent.withValues(alpha: 0.4) : const Color(0x0F000000)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                color: on ? AppColors.accentInk : AppColors.ink2)),
      ),
    );
  }

  Widget _clusterCard(List<Map<String, dynamic>> members) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    members.first['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2),
                  ),
                ),
                const SizedBox(width: 8),
                _countBadge(members.length),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x0D000000)),
          for (final m in members) _noteRow(m),
        ],
      ),
    );
  }

  Widget _ungroupedSection(List<Map<String, dynamic>> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Text('그 외',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                  letterSpacing: -0.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0x05000000),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [for (final m in notes) _noteRow(m)]),
        ),
      ],
    );
  }

  // 메모 한 줄. 행 클릭=열기/소환. 끝에 서랍 넣기/꺼내기 버튼.
  // 닫힘(서랍)은 칩·텍스트만 흐리게, 버튼은 또렷하게.
  Widget _noteRow(Map<String, dynamic> m) {
    final closed = m['open'] != true;
    final id = m['id'] as String;
    return InkWell(
      onTap: () => _open(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Opacity(
              opacity: closed ? 0.5 : 1.0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: StickyPalette.of(m['color'] as int),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x14000000)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: closed ? 0.55 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m['label'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                        ),
                        if (closed) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.inventory_2_outlined,
                              size: 11, color: Colors.black38),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      relativeDate(
                          DateTime.fromMillisecondsSinceEpoch(
                              m['updatedAt'] as int),
                          _now),
                      style:
                          const TextStyle(fontSize: 10.5, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _rowAction(id, closed),
          ],
        ),
      ),
    );
  }

  // 끝 버튼: 열림→서랍에 넣기, 서랍→꺼내기. (행 탭과 별개로 동작)
  Widget _rowAction(String id, bool closed) {
    return Tooltip(
      message: closed ? '꺼내기' : '서랍에 넣기',
      child: InkWell(
        onTap: () => closed ? _open(id) : _drawer(id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            closed ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
            size: 16,
            color: closed ? _accent : Colors.black38,
          ),
        ),
      ),
    );
  }

  Widget _countBadge(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$n',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _accent)),
      );

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('조건에 맞는 메모가 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black45)),
        ),
      );
}
