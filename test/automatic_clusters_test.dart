import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/automatic_clusters.dart';
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/suggested_clusters.dart';

void main() {
  const small = 'multilingual-e5-small-qint8';
  const base = 'multilingual-e5-base-qint8';
  HybridRelevanceResult result(double? semantic, {double hybrid = 1}) =>
      HybridRelevanceResult(
        score: hybrid,
        semanticScore: semantic,
        lexicalScore: 0.5,
        reasons: const ['공통 주제'],
        sharedKeywords: const ['주제'],
      );
  double lookup(Map<String, double> pairs, String a, String b) =>
      pairs[([a, b]..sort()).join('-')] ?? 0.8;

  test(
    'raw similarity separates strong cores despite saturated hybrid scores',
    () {
      final groups = AutomaticClusterEngine.build(
        ['a', 'b', 'c', 'd'],
        (a, b) => result(lookup({'a-b': 0.98, 'c-d': 0.97}, a, b)),
        modelId: small,
      );
      expect(groups.map((group) => group.ids.toSet()), [
        {'a', 'b'},
        {'c', 'd'},
      ]);
    },
  );

  test(
    'growth never merges cores with slightly weaker cross-topic similarity',
    () {
      final groups = AutomaticClusterEngine.build(['a', 'b', 'c', 'd'], (a, b) {
        final key = ([a, b]..sort()).join('-');
        return result(key == 'a-b' || key == 'c-d' ? 0.98 : 0.93);
      }, modelId: small);
      expect(groups, hasLength(2));
      expect(groups.every((group) => group.ids.length == 2), isTrue);
    },
  );

  test('an ambiguous note is left outside both cores', () {
    final scores = {
      'a-b': 0.98,
      'c-d': 0.98,
      'a-x': 0.91,
      'b-x': 0.91,
      'c-x': 0.905,
      'd-x': 0.905,
    };
    final groups = AutomaticClusterEngine.build(
      ['a', 'b', 'c', 'd', 'x'],
      (a, b) => result(lookup(scores, a, b)),
      modelId: small,
    );
    expect(groups.expand((group) => group.ids), isNot(contains('x')));
  });

  test('Base requires stronger separation than Small', () {
    final scores = {
      'a-b': 0.98,
      'c-d': 0.98,
      'a-x': 0.91,
      'b-x': 0.91,
      'c-x': 0.895,
      'd-x': 0.895,
    };
    final ids = ['a', 'b', 'c', 'd', 'x'];
    final smallGroups = AutomaticClusterEngine.build(
      ids,
      (a, b) => result(lookup(scores, a, b)),
      modelId: small,
    );
    final baseGroups = AutomaticClusterEngine.build(
      ids,
      (a, b) => result(lookup(scores, a, b)),
      modelId: base,
    );
    expect(smallGroups.expand((g) => g.ids), contains('x'));
    expect(baseGroups.expand((g) => g.ids), isNot(contains('x')));
  });

  test('one weak relationship blocks an otherwise high average addition', () {
    final scores = {'a-b': 0.98, 'a-x': 0.93, 'b-x': 0.86};
    final groups = AutomaticClusterEngine.build(
      ['a', 'b', 'x'],
      (a, b) => result(lookup(scores, a, b)),
      modelId: small,
    );
    expect(groups.single.ids.toSet(), {'a', 'b'});
  });

  test('added notes cannot recruit an ambiguous neighbor in the same pass', () {
    final scores = {
      'a-b': 0.98,
      'c-d': 0.98,
      'a-x': 0.93,
      'b-x': 0.93,
      'a-y': 0.90,
      'b-y': 0.90,
      'c-y': 0.895,
      'd-y': 0.895,
      'x-y': 0.93,
    };
    final groups = AutomaticClusterEngine.build(
      ['a', 'b', 'c', 'd', 'x', 'y'],
      (a, b) => result(lookup(scores, a, b)),
      modelId: small,
    );
    expect(groups.expand((g) => g.ids), contains('x'));
    expect(groups.expand((g) => g.ids), isNot(contains('y')));
  });

  test('dismissal excludes semantic seeds and keyword fallback', () {
    for (final semantic in [0.99, null]) {
      expect(
        AutomaticClusterEngine.build(
          ['a', 'b'],
          (_, _) => result(semantic),
          modelId: small,
          isDismissed: (_, _) => true,
        ),
        isEmpty,
      );
    }
  });

  test(
    'keyword fallback works without vectors but cannot revive rejected semantic pairs',
    () {
      expect(
        AutomaticClusterEngine.build(['a', 'b'], (_, _) => result(null)),
        hasLength(1),
      );
      expect(
        AutomaticClusterEngine.build(
          ['a', 'b'],
          (_, _) => result(0.91),
          modelId: small,
        ),
        isEmpty,
      );
    },
  );

  test(
    'uncalibrated models use conservative defaults and reject invalid similarities',
    () {
      expect(
        AutomaticClusterEngine.build(
          ['a', 'b'],
          (_, _) => result(0.95),
          modelId: 'community',
        ),
        isEmpty,
      );
      expect(
        AutomaticClusterEngine.build(
          ['a', 'b'],
          (_, _) => result(double.nan),
          modelId: small,
        ),
        isEmpty,
      );
    },
  );

  test(
    'output is deterministic, bounded, disjoint, and keeps its representative first',
    () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
      HybridRelevanceResult similarity(String a, String b) =>
          result((a == 'a' && b == 'b') || (a == 'b' && b == 'a') ? 0.98 : 0.9);
      final groups = AutomaticClusterEngine.build(
        ids,
        similarity,
        modelId: small,
        maxSize: 4,
      );
      final reversed = AutomaticClusterEngine.build(
        ids.reversed,
        similarity,
        modelId: small,
        maxSize: 4,
      );
      expect(groups.single.ids, reversed.single.ids);
      expect(groups.single.ids, hasLength(4));
      expect(groups.single.ids.first, 'a');
      expect(groups.single.ids.toSet(), hasLength(4));
      expect(
        () => AutomaticClusterEngine.build(ids, similarity, maxSize: 1),
        throwsArgumentError,
      );
    },
  );
  test('separated reciprocal neighbors need a third coherent member', () {
    final scores = {'a-b': 0.925, 'a-c': 0.90, 'b-c': 0.90};
    List<SuggestedCluster> build(
      List<String> ids, {
      String model = small,
      int max = 6,
    }) => AutomaticClusterEngine.build(
      ids,
      (a, b) => result(lookup(scores, a, b)),
      modelId: model,
      maxSize: max,
    );
    expect(build(['a', 'b', 'c', 'x']).single.ids.toSet(), {'a', 'b', 'c'});
    expect(build(['a', 'b', 'x']), isEmpty);
    expect(build(['a', 'b', 'c'], model: base), isEmpty);
    expect(build(['a', 'b', 'c'], max: 2), isEmpty);
  });

  test('equally close neighbors do not manufacture a weak seed', () {
    expect(
      AutomaticClusterEngine.build(
        ['a', 'b', 'c', 'd'],
        (_, _) => result(0.92),
        modelId: small,
      ),
      isEmpty,
    );
  });

  test(
    'already assigned notes still compete with residual seed candidates',
    () {
      final scores = {
        'a-b': 0.98,
        'c-d': 0.92,
        'a-c': 0.925,
        'c-e': 0.89,
        'd-e': 0.89,
      };
      final groups = AutomaticClusterEngine.build(
        ['a', 'b', 'c', 'd', 'e'],
        (a, b) => result(lookup(scores, a, b)),
        modelId: small,
      );
      expect(groups.single.ids.toSet(), {'a', 'b'});
    },
  );

  test('residual growth respects dismissal, coherence and input order', () {
    final scores = {
      'a-b': 0.925,
      'a-c': 0.90,
      'b-c': 0.90,
      'a-d': 0.89,
      'b-d': 0.89,
      'c-d': 0.87,
    };
    final ids = ['a', 'b', 'c', 'd'];
    final forward = AutomaticClusterEngine.build(
      ids,
      (a, b) => result(lookup(scores, a, b)),
      modelId: small,
    );
    final reverse = AutomaticClusterEngine.build(
      ids.reversed,
      (a, b) => result(lookup(scores, a, b)),
      modelId: small,
    );
    expect(forward.single.ids, reverse.single.ids);
    expect(forward.single.ids.toSet(), {'a', 'b', 'c'});
    expect(
      AutomaticClusterEngine.build(
        ids,
        (a, b) => result(lookup(scores, a, b)),
        modelId: small,
        isDismissed: (a, b) => {a, b}.containsAll(['b', 'c']),
      ).single.ids.toSet(),
      {'a', 'b', 'd'},
    );
  });
}
