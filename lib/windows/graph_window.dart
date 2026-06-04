import 'dart:math';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../ipc.dart';
import '../sticky_palette.dart';

class GraphWindowApp extends StatelessWidget {
  final List<Map<String, dynamic>> nodes; // {id,label,color}
  final List<Map<String, dynamic>> edges; // {a,b}
  const GraphWindowApp({super.key, required this.nodes, required this.edges});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '지식 그래프',
      theme: ThemeData(useMaterial3: true),
      home: GraphWindow(nodes: nodes, edges: edges),
    );
  }
}

class GraphWindow extends StatefulWidget {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  const GraphWindow({super.key, required this.nodes, required this.edges});

  @override
  State<GraphWindow> createState() => _GraphWindowState();
}

class _GraphWindowState extends State<GraphWindow> {
  static const _main =
      WindowMethodChannel(kMainChannel, mode: ChannelMode.unidirectional);
  static const double _w = 1400;
  static const double _h = 1000;

  final Map<String, Offset> _pos = {};

  @override
  void initState() {
    super.initState();
    _layout();
  }

  // Fruchterman-Reingold force-directed layout (작은 그래프라 한 번 계산).
  void _layout() {
    final ids = widget.nodes.map((n) => n['id'] as String).toList();
    if (ids.isEmpty) return;
    final rnd = Random(7);
    for (final id in ids) {
      _pos[id] = Offset(200 + rnd.nextDouble() * (_w - 400),
          200 + rnd.nextDouble() * (_h - 400));
    }
    final center = const Offset(_w / 2, _h / 2);
    const k = 200.0; // 이상적 엣지 길이
    for (var iter = 0; iter < 350; iter++) {
      final disp = {for (final id in ids) id: Offset.zero};
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          var delta = _pos[ids[i]]! - _pos[ids[j]]!;
          var dist = max(delta.distance, 0.01);
          final f = k * k / dist;
          final dir = delta / dist;
          disp[ids[i]] = disp[ids[i]]! + dir * f;
          disp[ids[j]] = disp[ids[j]]! - dir * f;
        }
      }
      for (final e in widget.edges) {
        final a = e['a'] as String, b = e['b'] as String;
        if (!_pos.containsKey(a) || !_pos.containsKey(b)) continue;
        final delta = _pos[a]! - _pos[b]!;
        final dist = max(delta.distance, 0.01);
        final f = dist * dist / k;
        final dir = delta / dist;
        disp[a] = disp[a]! - dir * f;
        disp[b] = disp[b]! + dir * f;
      }
      final temp = (1 - iter / 350) * 28 + 2;
      for (final id in ids) {
        disp[id] = disp[id]! + (center - _pos[id]!) * 0.02; // 중심 중력
        final d = disp[id]!;
        final len = max(d.distance, 0.01);
        _pos[id] = _pos[id]! + d / len * min(len, temp);
      }
    }
  }

  Future<void> _open(String id) => _main.invokeMethod('focusSticky', id);

  @override
  Widget build(BuildContext context) {
    if (widget.edges.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBFAF6),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              '아직 연결이 없어요.\n메모에서 ✨ 관련 제안의 [연결]을 누르면\n여기에 지식 그래프가 자라요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black45, height: 1.5),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF6),
      body: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(400),
        minScale: 0.3,
        maxScale: 2.5,
        child: SizedBox(
          width: _w,
          height: _h,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _EdgePainter(widget.edges, _pos)),
              ),
              for (final n in widget.nodes) _nodeChip(n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nodeChip(Map<String, dynamic> n) {
    final id = n['id'] as String;
    final p = _pos[id];
    if (p == null) return const SizedBox.shrink();
    const w = 150.0;
    return Positioned(
      left: p.dx - w / 2,
      top: p.dy - 22,
      width: w,
      child: GestureDetector(
        onTap: () => _open(id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: StickyPalette.of(n['color'] as int),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            n['label'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  final List<Map<String, dynamic>> edges;
  final Map<String, Offset> pos;
  _EdgePainter(this.edges, this.pos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1.4;
    for (final e in edges) {
      final a = pos[e['a']], b = pos[e['b']];
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => false;
}
