// Frozen v2 evaluator baseline. Do not tune this copy.
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/suggested_clusters.dart';

/// Calibrated on the development fixture, before evaluating unseen topics.
/// These are similarity boundaries, not probabilities or accuracy percentages.
class V2ClusterCalibration {
  const V2ClusterCalibration({
    required this.seedThreshold,
    required this.seedFloor,
    required this.additionThreshold,
    required this.additionFloor,
    required this.margin,
  });

  final double seedThreshold;
  final double seedFloor;
  final double additionThreshold;
  final double additionFloor;
  final double margin;

  static V2ClusterCalibration forModel(String? modelId) => switch (modelId) {
    'multilingual-e5-small-qint8' => const V2ClusterCalibration(
      seedThreshold: 0.94,
      seedFloor: 0.92,
      additionThreshold: 0.88,
      additionFloor: 0.88,
      margin: 0.01,
    ),
    'multilingual-e5-base-qint8' => const V2ClusterCalibration(
      seedThreshold: 0.94,
      seedFloor: 0.92,
      additionThreshold: 0.88,
      additionFloor: 0.88,
      margin: 0.02,
    ),
    // An uncalibrated community model must not inherit the most permissive cutoffs.
    _ => const V2ClusterCalibration(
      seedThreshold: 0.96,
      seedFloor: 0.94,
      additionThreshold: 0.90,
      additionFloor: 0.90,
      margin: 0.03,
    ),
  };
}

/// Build strong semantic cores first. Grow them only when a note has a clear
/// preference for one core. Growth never merges cores and newly added notes do
/// not become evidence for recruiting further notes in the same pass.
class AutomaticClusterEngineV2 {
  static const policyVersion = 2;
  static List<SuggestedCluster> build(
    Iterable<String> sourceIds,
    HybridRelevanceResult Function(String, String) relevance, {
    String? modelId,
    bool Function(String, String)? isDismissed,
    int maxSize = 6,
  }) {
    if (maxSize < 2) {
      throw ArgumentError.value(maxSize, 'maxSize', 'Must be at least 2');
    }
    final ids = sourceIds.toSet().toList()..sort();
    final calibration = V2ClusterCalibration.forModel(modelId);
    double semantic(String a, String b) {
      if (isDismissed?.call(a, b) ?? false) return -1;
      final score = relevance(a, b).semanticScore;
      return score != null && score.isFinite ? score : -1;
    }

    final cores = SuggestedClusterEngine.build(
      ids,
      semantic,
      pairThreshold: calibration.seedThreshold,
      minimumCrossScore: calibration.seedFloor,
      maxSize: maxSize,
    );
    final groups = [for (final core in cores) List<String>.of(core.ids)];
    final assigned = groups.expand((group) => group).toSet();
    final additions = <({String id, int group, double score})>[];
    for (final id in ids.where((id) => !assigned.contains(id))) {
      final candidates = <({int group, double score})>[];
      for (var i = 0; i < cores.length; i++) {
        final scores = [for (final member in cores[i].ids) semantic(id, member)]
          ..sort((a, b) => b.compareTo(a));
        final support = scores.take(3).toList();
        candidates.add((
          group: i,
          score: support.reduce((a, b) => a + b) / support.length,
        ));
      }
      candidates.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.group.compareTo(b.group);
      });
      if (candidates.isEmpty ||
          candidates.first.score < calibration.additionThreshold) {
        continue;
      }
      if (candidates.length > 1 &&
          candidates.first.score - candidates[1].score < calibration.margin) {
        continue;
      }
      additions.add((
        id: id,
        group: candidates.first.group,
        score: candidates.first.score,
      ));
    }
    additions.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });
    for (final addition in additions) {
      final group = groups[addition.group];
      if (group.length >= maxSize ||
          group.any(
            (member) =>
                semantic(addition.id, member) < calibration.additionFloor,
          )) {
        continue;
      }
      group.add(addition.id);
      assigned.add(addition.id);
    }

    // During indexing, keyword recommendations remain available. A rejected
    // semantic pair must not sneak back through its saturated hybrid score.
    final lexical = SuggestedClusterEngine.build(
      ids.where((id) => !assigned.contains(id)),
      (a, b) {
        if (isDismissed?.call(a, b) ?? false) return -1;
        final result = relevance(a, b);
        return result.semanticScore == null ? result.score : -1;
      },
      pairThreshold: HybridRelevance.suggestionThreshold,
      minimumCrossScore: 0.50,
      maxSize: maxSize,
    );
    final result = <SuggestedCluster>[
      for (final group in groups) _cluster(group, semantic),
      ...lexical,
    ];
    result.sort((a, b) {
      final bySize = b.ids.length.compareTo(a.ids.length);
      if (bySize != 0) return bySize;
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.ids.first.compareTo(b.ids.first);
    });
    return result;
  }

  static SuggestedCluster _cluster(List<String> group, PairSimilarity score) {
    double centrality(String id) => group
        .where((other) => other != id)
        .fold<double>(0, (sum, other) => sum + score(id, other));
    final ordered = List<String>.of(group)
      ..sort((a, b) {
        final byCentrality = centrality(b).compareTo(centrality(a));
        return byCentrality != 0 ? byCentrality : a.compareTo(b);
      });
    return SuggestedCluster(ordered, _cohesion(ordered, score));
  }

  static double _cohesion(List<String> ids, PairSimilarity score) {
    var sum = 0.0;
    var pairs = 0;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        sum += score(ids[i], ids[j]);
        pairs++;
      }
    }
    return sum / pairs;
  }
}
