import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/suggested_clusters.dart';

void main() {
  double scores(Map<String, double> values, String a, String b) =>
      values['${[a, b]..sort()}'] ?? 0;

  test('cohesive notes form one group with central note first', () {
    final values = <String, double>{
      '[a, b]': 0.90,
      '[a, c]': 0.86,
      '[b, c]': 0.92,
    };
    final groups = SuggestedClusterEngine.build([
      'a',
      'b',
      'c',
    ], (a, b) => scores(values, a, b));
    expect(groups, hasLength(1));
    expect(groups.single.ids, hasLength(3));
    expect(groups.single.ids.first, 'b', reason: 'b has highest centrality');
    expect(groups.single.score, closeTo((0.90 + 0.86 + 0.92) / 3, 0.0001));
  });

  test('does not chain through one similar neighbor', () {
    final values = <String, double>{
      '[a, b]': 0.92,
      '[b, c]': 0.91,
      '[a, c]': 0.30,
    };
    final groups = SuggestedClusterEngine.build([
      'a',
      'b',
      'c',
    ], (a, b) => scores(values, a, b));
    expect(groups, hasLength(1));
    expect(groups.single.ids.toSet(), {'a', 'b'});
  });

  test('keeps separate topics and assigns each note once', () {
    final values = <String, double>{
      '[a, b]': 0.93,
      '[c, d]': 0.91,
      '[b, c]': 0.50,
    };
    final groups = SuggestedClusterEngine.build([
      'a',
      'b',
      'c',
      'd',
    ], (a, b) => scores(values, a, b));
    expect(groups, hasLength(2));
    final ids = groups.expand((g) => g.ids).toList();
    expect(ids.toSet(), {'a', 'b', 'c', 'd'});
    expect(ids.length, ids.toSet().length);
  });

  test('honors maximum group size', () {
    final groups = SuggestedClusterEngine.build(
      ['a', 'b', 'c', 'd'],
      (a, b) => 0.95,
      maxSize: 3,
    );
    expect(groups.every((g) => g.ids.length <= 3), isTrue);
  });
}
