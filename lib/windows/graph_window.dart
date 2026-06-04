import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../ipc.dart';
import '../sticky_palette.dart';

/// 연결된 메모를 "주제 묶음(클러스터)"으로 보여주는 창.
/// 떠다니는 그래프 대신, 회고/소환에 실제로 쓰는 컬렉션 목록.
class GraphWindowApp extends StatelessWidget {
  final List<Map<String, dynamic>> nodes; // {id,label,color}
  final List<Map<String, dynamic>> edges; // {a,b}
  const GraphWindowApp({super.key, required this.nodes, required this.edges});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '묶음',
      theme: ThemeData(useMaterial3: true),
      home: ClusterWindow(nodes: nodes, edges: edges),
    );
  }
}

class ClusterWindow extends StatelessWidget {
  static const _main =
      WindowMethodChannel(kMainChannel, mode: ChannelMode.unidirectional);
  static const Color _accent = Color(0xFFB58236);
  static const Color _bg = Color(0xFFFBFAF6);

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  const ClusterWindow({super.key, required this.nodes, required this.edges});

  Future<void> _open(String id) => _main.invokeMethod('focusSticky', id);

  // 연결 그래프의 연결요소(컴포넌트)를 묶음으로. 큰 묶음 먼저, 묶음 안은 연결 많은 순.
  List<List<Map<String, dynamic>>> _clusters() {
    final byId = {for (final n in nodes) n['id'] as String: n};
    final adj = <String, Set<String>>{};
    for (final e in edges) {
      final a = e['a'] as String, b = e['b'] as String;
      (adj[a] ??= {}).add(b);
      (adj[b] ??= {}).add(a);
    }
    final seen = <String>{};
    final out = <List<Map<String, dynamic>>>[];
    for (final n in nodes) {
      final id = n['id'] as String;
      if (seen.contains(id)) continue;
      final comp = <String>[];
      final queue = <String>[id];
      seen.add(id);
      while (queue.isNotEmpty) {
        final u = queue.removeLast();
        comp.add(u);
        for (final v in adj[u] ?? const <String>{}) {
          if (seen.add(v)) queue.add(v);
        }
      }
      // 연결 많은(허브) 순으로 정렬해 대표가 위로.
      comp.sort((a, b) =>
          (adj[b]?.length ?? 0).compareTo(adj[a]?.length ?? 0));
      out.add([for (final cid in comp) byId[cid]!]);
    }
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final clusters = _clusters();
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: clusters.isEmpty ? _empty() : _list(clusters),
      ),
    );
  }

  Widget _list(List<List<Map<String, dynamic>>> clusters) {
    final total = clusters.fold<int>(0, (s, c) => s + c.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('묶음',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text('${clusters.length}개 주제 · 메모 $total개',
                  style: const TextStyle(fontSize: 13, color: Colors.black45)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: clusters.length,
            separatorBuilder: (_, i) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _clusterCard(clusters[i]),
          ),
        ),
      ],
    );
  }

  Widget _clusterCard(List<Map<String, dynamic>> members) {
    final title = members.first['label'] as String; // 허브 메모를 대표로
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0F000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더: 대표 주제 + 개수 배지
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 14, 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${members.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x0D000000)),
          for (final m in members) _memberRow(m),
        ],
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> m) {
    return InkWell(
      onTap: () => _open(m['id'] as String),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: StickyPalette.of(m['color'] as int),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x14000000)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                m['label'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const Icon(Icons.north_east_rounded,
                size: 14, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bubble_chart_outlined, size: 32, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                '아직 묶음이 없어요.\n메모에서 ✨ 관련 제안의 [연결]을 누르면\n관련된 메모가 주제로 묶여요.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: Colors.black45, height: 1.5),
              ),
            ],
          ),
        ),
      );
}
