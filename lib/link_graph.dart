/// 승인된 연결(양방향 인접)만 담는 순수 그래프. id만 다루고 표현(preview/color)은
/// 모른다 → 컨트롤러가 id→노드 매핑. DB/IPC 의존 없음 → 단위 테스트 용이.
class LinkGraph {
  final Map<String, Set<String>> _adj = {};

  /// 무방향 엣지 추가.
  void addEdge(String a, String b) {
    (_adj[a] ??= <String>{}).add(b);
    (_adj[b] ??= <String>{}).add(a);
  }

  /// 노드와 그에 닿는 모든 엣지 제거.
  void remove(String id) {
    _adj.remove(id);
    for (final set in _adj.values) {
      set.remove(id);
    }
  }

  Set<String> neighbors(String id) => _adj[id] ?? const <String>{};
  int degree(String id) => _adj[id]?.length ?? 0;
  bool contains(String id) => _adj.containsKey(id);

  /// 중복 없는 무방향 엣지 목록 (a<b 정규화). 전체 보기 그래프용.
  List<({String a, String b})> uniqueEdges() {
    final seen = <String>{};
    final out = <({String a, String b})>[];
    _adj.forEach((a, set) {
      for (final b in set) {
        final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
        if (seen.add(key)) out.add((a: a, b: b));
      }
    });
    return out;
  }

  /// 연결요소(묶음) 목록 — 멤버 2개 이상만, 큰 묶음 먼저.
  /// 각 묶음 내부는 degree(연결 수) 내림차순.
  List<List<String>> clusters() {
    final seen = <String>{};
    final out = <List<String>>[];
    for (final start in _adj.keys) {
      if (seen.contains(start)) continue;
      if (neighbors(start).isEmpty) continue;
      final comp = <String>[];
      final q = <String>[start];
      seen.add(start);
      while (q.isNotEmpty) {
        final u = q.removeLast();
        comp.add(u);
        for (final v in neighbors(u)) {
          if (seen.add(v)) q.add(v);
        }
      }
      comp.sort((a, b) => degree(b).compareTo(degree(a)));
      if (comp.length >= 2) out.add(comp);
    }
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  /// id와 같은 묶음의 *다른* 노드들 (degree 내림차순). 연결 없으면 빈 리스트.
  List<String> sameCluster(String id) {
    if (!contains(id)) return const [];
    final seen = <String>{id};
    final q = <String>[id];
    final comp = <String>[];
    while (q.isNotEmpty) {
      final u = q.removeLast();
      for (final v in neighbors(u)) {
        if (seen.add(v)) {
          q.add(v);
          comp.add(v);
        }
      }
    }
    comp.sort((a, b) => degree(b).compareTo(degree(a)));
    return comp;
  }
}
