/// 아직 사용자가 확정하지 않은 의미 기반 추천 묶음.
/// ids 첫 번째는 그룹의 대표 메모(medoid)다.
class SuggestedCluster {
  const SuggestedCluster(this.ids, this.score);

  final List<String> ids;
  final double score; // 그룹 내부 모든 쌍의 평균 유사도
}

typedef PairSimilarity = double Function(String a, String b);

/// pairwise 유사도를 작은 응집 묶음으로 만드는 순수 알고리즘.
/// 단순 connected-components와 달리 새 멤버가 그룹 전체와 가까워야 하므로
/// A~B, B~C만 비슷한 semantic chaining을 막는다.
class SuggestedClusterEngine {
  const SuggestedClusterEngine._();

  static List<SuggestedCluster> build(
    Iterable<String> sourceIds,
    PairSimilarity similarity, {
    double pairThreshold = 0.84,
    double minimumCrossScore = 0.80,
    int maxSize = 6,
  }) {
    final ids = sourceIds.toSet().toList()..sort();
    final pairs = <({String a, String b, double score})>[];
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final score = similarity(ids[i], ids[j]);
        if (score >= pairThreshold) {
          pairs.add((a: ids[i], b: ids[j], score: score));
        }
      }
    }
    pairs.sort((x, y) {
      final byScore = y.score.compareTo(x.score);
      if (byScore != 0) return byScore;
      final byA = x.a.compareTo(y.a);
      return byA != 0 ? byA : x.b.compareTo(y.b);
    });

    final groups = <List<String>>[];
    final membership = <String, List<String>>{};
    for (final pair in pairs) {
      final ga = membership[pair.a];
      final gb = membership[pair.b];
      if (identical(ga, gb) && ga != null) continue;

      if (ga == null && gb == null) {
        final group = <String>[pair.a, pair.b];
        groups.add(group);
        membership[pair.a] = group;
        membership[pair.b] = group;
        continue;
      }

      if (ga == null || gb == null) {
        final group = ga ?? gb!;
        final candidate = ga == null ? pair.a : pair.b;
        if (group.length >= maxSize ||
            !_coherent(
              group,
              [candidate],
              similarity,
              pairThreshold,
              minimumCrossScore,
            )) {
          continue;
        }
        group.add(candidate);
        membership[candidate] = group;
        continue;
      }

      if (ga.length + gb.length > maxSize ||
          !_coherent(ga, gb, similarity, pairThreshold, minimumCrossScore)) {
        continue;
      }
      ga.addAll(gb);
      groups.remove(gb);
      for (final id in gb) {
        membership[id] = ga;
      }
    }

    final result = <SuggestedCluster>[];
    for (final group in groups) {
      if (group.length < 2) continue;
      final ordered = [...group]
        ..sort((a, b) {
          final byCentrality = _averageTo(
            a,
            group,
            similarity,
          ).compareTo(_averageTo(b, group, similarity));
          return byCentrality != 0 ? -byCentrality : a.compareTo(b);
        });
      result.add(SuggestedCluster(ordered, _cohesion(group, similarity)));
    }
    result.sort((a, b) {
      final bySize = b.ids.length.compareTo(a.ids.length);
      if (bySize != 0) return bySize;
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.ids.first.compareTo(b.ids.first);
    });
    return result;
  }

  static bool _coherent(
    List<String> a,
    List<String> b,
    PairSimilarity similarity,
    double averageThreshold,
    double minimumThreshold,
  ) {
    var sum = 0.0;
    var count = 0;
    var minimum = double.infinity;
    for (final x in a) {
      for (final y in b) {
        final score = similarity(x, y);
        sum += score;
        count++;
        if (score < minimum) minimum = score;
      }
    }
    return count > 0 &&
        sum / count >= averageThreshold &&
        minimum >= minimumThreshold;
  }

  static double _averageTo(
    String id,
    List<String> group,
    PairSimilarity similarity,
  ) {
    var sum = 0.0;
    var count = 0;
    for (final other in group) {
      if (other == id) continue;
      sum += similarity(id, other);
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  static double _cohesion(List<String> group, PairSimilarity similarity) {
    var sum = 0.0;
    var count = 0;
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        sum += similarity(group[i], group[j]);
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }
}
