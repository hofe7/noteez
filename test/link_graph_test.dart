import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/link_graph.dart';

void main() {
  group('LinkGraph', () {
    test('addEdge 는 무방향 (양쪽 이웃)', () {
      final g = LinkGraph()..addEdge('a', 'b');
      expect(g.neighbors('a'), {'b'});
      expect(g.neighbors('b'), {'a'});
      expect(g.degree('a'), 1);
    });

    test('remove 는 노드 + 닿는 엣지 제거', () {
      final g = LinkGraph()
        ..addEdge('a', 'b')
        ..addEdge('b', 'c');
      g.remove('b');
      expect(g.contains('b'), isFalse);
      expect(g.neighbors('a'), isEmpty);
      expect(g.neighbors('c'), isEmpty);
    });

    test('uniqueEdges 는 중복 없는 무방향 쌍', () {
      final g = LinkGraph()
        ..addEdge('a', 'b')
        ..addEdge('b', 'a') // 중복
        ..addEdge('b', 'c');
      final pairs = g
          .uniqueEdges()
          .map((e) => [e.a, e.b]..sort())
          .map((p) => p.join('-'))
          .toSet();
      expect(pairs, {'a-b', 'b-c'});
    });

    test('clusters: 멤버 2+ 만, 큰 묶음 먼저, 내부 degree 내림차순', () {
      final g = LinkGraph()
        // 묶음1: a-b-c-d (b가 허브: degree 3)
        ..addEdge('b', 'a')
        ..addEdge('b', 'c')
        ..addEdge('b', 'd')
        // 묶음2: x-y (각 degree 1)
        ..addEdge('x', 'y')
        // 고립 엣지 없음(단일 노드는 클러스터 아님)
        ;
      final cl = g.clusters();
      expect(cl.length, 2);
      expect(cl[0].length, 4, reason: '큰 묶음 먼저');
      expect(cl[0].first, 'b', reason: '허브(degree 최다)가 앞');
      expect(cl[1].toSet(), {'x', 'y'});
    });

    test('sameCluster: 자신 제외, degree 내림차순', () {
      final g = LinkGraph()
        ..addEdge('b', 'a')
        ..addEdge('b', 'c')
        ..addEdge('b', 'd');
      final same = g.sameCluster('a');
      expect(same.contains('a'), isFalse);
      expect(same.toSet(), {'b', 'c', 'd'});
      expect(same.first, 'b', reason: '연결 가장 많은 b 먼저');
      expect(g.sameCluster('없는id'), isEmpty);
    });
  });
}
