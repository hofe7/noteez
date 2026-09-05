import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/automatic_clusters.dart';
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/services/recommendation_service.dart';

List<Sticky> notes(int count) => [
  for (var i = 0; i < count; i++)
    Sticky(
      id: 'n$i',
      blocks: [TextBlock(id: 'b$i', text: '프로젝트 ${i % 5} 회의록 배포 일정 테스트 $i')],
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    ),
];
RecommendationInput input(int count) => RecommendationInput(
  notes: notes(count),
  vectors: {
    for (var i = 0; i < count; i++)
      'n$i': List<double>.generate(384, (j) => j == i % 5 ? 1 : 0),
  },
  modelId: 'multilingual-e5-small-qint8',
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'unordered-pair scan matches per-note recommendations including ties and exclusions',
    () {
      final data = input(35);
      final engine = ConnectionEngine.forRecommendations(
        data.modelId,
        data.vectors,
      );
      final memberships = {'n0': 'g', 'n2': 'g'};
      bool linked(String a, String b) =>
          recommendationPair(a, b) == recommendationPair('n3', 'n8');
      bool dismissed(String a, String b) => a == 'n7' || b == 'n7';
      final expected = <String, Map<String, dynamic>>{};
      for (final note in data.notes) {
        final c = engine.connectionFor(
          note.id,
          data.notes,
          isDismissed: dismissed,
          exclude: {
            for (final other in data.notes)
              if (linked(note.id, other.id) ||
                  (memberships[note.id] != null &&
                      memberships[note.id] == memberships[other.id]))
                other.id,
          },
        );
        if (c == null) continue;
        final ids = [note.id, c.id]..sort();
        final key = jsonEncode(ids);
        if ((expected[key]?['score'] as double? ?? -1) >= c.score) continue;
        expected[key] = {
          'a': ids[0],
          'b': ids[1],
          'score': c.score,
          'reasons': c.reasons,
        };
      }
      final actual = engine.referenceSuggestions(
        data.notes,
        isLinked: linked,
        isDismissed: dismissed,
        memberships: memberships,
      );
      expect({
        for (final pair in actual) jsonEncode([pair['a'], pair['b']]): pair,
      }, expected);
    },
  );

  test(
    'semantic fast path preserves the original clustering policy for all model calibrations',
    () {
      final data = input(42);
      final byId = {for (final n in data.notes) n.id: n};
      for (final model in [
        null,
        'multilingual-e5-small-qint8',
        'multilingual-e5-base-qint8',
        'community',
      ]) {
        final engine = ConnectionEngine.forRecommendations(model, data.vectors);
        bool dismissed(String a, String b) => a == 'n9' || b == 'n9';
        final baseline = AutomaticClusterEngine.build(
          byId.keys,
          (a, b) {
            final av = data.vectors[a]!, bv = data.vectors[b]!;
            var dot = 0.0;
            for (var i = 0; i < av.length; i++) {
              dot += av[i] * bv[i];
            }
            return HybridRelevance.evaluate(
              byId[a]!,
              byId[b]!,
              semanticScore: dot,
            );
          },
          modelId: model,
          isDismissed: dismissed,
        );
        final actual = engine.suggestedClusters(
          data.notes,
          isDismissed: dismissed,
        );
        expect(
          [
            for (final g in actual) [g.ids, g.score],
          ],
          [
            for (final g in baseline) [g.ids, g.score],
          ],
        );
      }
    },
  );

  test(
    'semantic cache invalidates after replacing vectors and changing the note set',
    () {
      final data = input(12);
      final engine = ConnectionEngine.forRecommendations(
        data.modelId,
        data.vectors,
      );
      engine.suggestedClusters(data.notes);
      engine.seed('n1', 'new', List<double>.filled(384, 0));
      engine.remove('n2');
      final remaining = data.notes
          .where((n) => n.id != 'n2')
          .toList()
          .reversed
          .toList();
      final fresh = ConnectionEngine.forRecommendations(
        data.modelId,
        engine.recommendationVectors,
      );
      expect(
        engine.referenceSuggestions(remaining, isLinked: (_, _) => false),
        fresh.referenceSuggestions(remaining, isLinked: (_, _) => false),
      );
    },
  );

  test(
    'moving an unindexed note does not invalidate recommendation vectors',
    () async {
      final engine = ConnectionEngine();
      final note = notes(1).single;
      await engine.index(note);
      final before = engine.recommendationVersion;
      await engine.index(note.copyWith(x: 99, width: 400));
      expect(engine.recommendationVersion, before);
      await engine.close();
    },
  );

  test(
    'worker performs the same calculation without blocking main-isolate timers',
    () async {
      final data = input(500);
      final worker = RecommendationWorker();
      addTearDown(worker.close);
      var beats = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 2),
        (_) => beats++,
      );
      final result = await worker.run(data);
      timer.cancel();
      expect(beats, greaterThan(0));
      expect(result, calculateRecommendations(data));
    },
  );

  test(
    'closing a spawning worker rejects the request and releases its isolate',
    () async {
      final worker = RecommendationWorker();
      final pending = worker.run(input(500));
      final expectation = expectLater(pending, throwsStateError);
      worker.close();
      await expectation;
    },
  );

  test('coalesces changes and never publishes an obsolete result', () async {
    final requests = <RecommendationInput>[];
    final gates = <Completer<Map<String, dynamic>>>[];
    final service = RecommendationService(
      debounce: Duration.zero,
      onChanged: () {},
      compute: (data) {
        requests.add(data);
        final gate = Completer<Map<String, dynamic>>();
        gates.add(gate);
        return gate.future;
      },
    );
    addTearDown(service.close);
    service.update('first', () => input(1));
    await tick();
    service.update('second', () => input(2));
    service.update('third', () => input(3));
    gates.first.complete({'obsolete': true});
    await tick();
    expect(requests.map((r) => r.notes.length), [1, 3]);
    expect(service.result, isNull);
    gates.last.complete({'latest': true});
    await tick();
    expect(service.result, {'latest': true});
    service.update('third', () => input(4));
    await tick();
    expect(requests, hasLength(2));
    expect(service.busy, isFalse);
  });

  test(
    'failed recommendation can be retried and close suppresses late delivery',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      var calls = 0, published = 0;
      final service = RecommendationService(
        debounce: Duration.zero,
        onChanged: () => published++,
        compute: (_) {
          if (++calls == 1) return Future.error(StateError('worker failed'));
          return gate.future;
        },
      );
      service.update('same', () => input(1));
      await tick();
      expect(service.error, isNotNull);
      service.retry();
      service.update('same', () => input(1));
      await tick();
      service.close();
      gate.complete({'late': true});
      await tick();
      expect(published, 1);
      expect(service.result, isNull);
    },
  );
}
