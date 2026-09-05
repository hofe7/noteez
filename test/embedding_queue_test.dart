import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/embed/embedding_worker.dart';
import 'package:noteez/model_manager.dart';
import 'package:noteez/models/model_catalog.dart';
import 'package:noteez/models/sticky.dart';

class ControlledEmbedder implements TextEmbedder {
  final calls = <String>[];
  final results = <Completer<List<double>>>[];
  @override
  Future<List<double>> embed(String text) {
    calls.add(text);
    final result = Completer<List<double>>();
    results.add(result);
    return result.future;
  }

  @override
  Future<void> close() async {}
}

void main() {
  Sticky note(String id, String text) => Sticky(
    id: id,
    blocks: [TextBlock(id: id, text: text)],
    colorIndex: 0,
    x: 0,
    y: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  InstalledModel model(int index) => InstalledModel(
    profile: ModelCatalog.models[index],
    modelPath: 'model-$index',
    tokenizerPath: 'tokens',
  );
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test(
    'superseded edits skip inference and stale results never persist',
    () async {
      final worker = ControlledEmbedder();
      final engine = ConnectionEngine(embedderFactory: (_) => worker)
        ..selectModel(model(0));
      final hashes = <String>[];
      engine.onPersist = (_, hash, _) async => hashes.add(hash);
      final old = engine.index(note('n', 'old'));
      await tick();
      final middle = engine.index(note('n', 'middle'));
      final latest = engine.index(note('n', 'latest'));
      worker.results[0].complete([1, 0]);
      await tick();
      expect(worker.calls, ['passage: old', 'passage: latest']);
      expect(hashes, isEmpty);
      worker.results[1].complete([0, 1]);
      await Future.wait([old, middle, latest]);
      expect(hashes, [engine.embeddingHash(note('n', 'latest'))]);
      await engine.close();
    },
  );

  test('deletion during inference cannot recreate an embedding', () async {
    final worker = ControlledEmbedder();
    final engine = ConnectionEngine(embedderFactory: (_) => worker)
      ..selectModel(model(0));
    var persisted = false;
    engine.onPersist = (_, _, _) async => persisted = true;
    final indexing = engine.index(note('n', 'deleted'));
    await tick();
    engine.remove('n');
    worker.results.single.complete([1, 0]);
    await indexing;
    expect(persisted, isFalse);
    await engine.close();
  });

  test(
    'switching models discards in-flight results from the previous model',
    () async {
      final workers = [ControlledEmbedder(), ControlledEmbedder()];
      final engine = ConnectionEngine(
        embedderFactory: (m) =>
            workers[m.profile.id == model(0).profile.id ? 0 : 1],
      );
      engine.selectModel(model(0));
      final hashes = <String>[];
      engine.onPersist = (_, hash, _) async => hashes.add(hash);
      final old = engine.index(note('n', 'text'));
      await tick();
      engine.selectModel(model(1));
      final latest = engine.index(note('n', 'text'));
      workers[0].results.single.complete([1, 0]);
      await tick();
      expect(hashes, isEmpty);
      workers[1].results.single.complete([0, 1]);
      await Future.wait([old, latest]);
      expect(hashes, hasLength(1));
      await engine.close();
    },
  );

  test(
    'startup snapshot cannot overwrite a note edited during warmup',
    () async {
      final worker = ControlledEmbedder();
      final engine = ConnectionEngine(embedderFactory: (_) => worker)
        ..selectModel(model(0));
      final warming = engine.warmup([
        note('a', 'first'),
        note('b', 'outdated'),
      ]);
      await tick();
      final editing = engine.index(note('b', 'newest'));
      worker.results[0].complete([1, 0]);
      await tick();
      expect(worker.calls, ['passage: first', 'passage: newest']);
      worker.results[1].complete([0, 1]);
      await Future.wait([warming, editing]);
      expect(worker.calls, hasLength(2));
      await engine.close();
    },
  );

  test(
    'inference failure does not poison the queue for subsequent notes',
    () async {
      final worker = ControlledEmbedder();
      final engine = ConnectionEngine(embedderFactory: (_) => worker)
        ..selectModel(model(0));
      final failing = engine.index(note('a', 'failure'));
      final expected = expectLater(failing, throwsStateError);
      await tick();
      final next = engine.index(note('b', 'works'));
      worker.results[0].completeError(StateError('runtime error'));
      await tick();
      worker.results[1].complete([1, 0]);
      await expected;
      await next;
      expect(engine.ready, isTrue);
      await engine.close();
    },
  );
}
