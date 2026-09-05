import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/embed/document_embedding.dart';
import 'package:noteez/embed/unigram_tokenizer.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/embed/embedding_worker.dart';
import 'package:noteez/model_manager.dart';
import 'package:noteez/models/model_catalog.dart';
import 'package:noteez/models/sticky.dart';

class QueryEmbedder implements TextEmbedder {
  @override
  Future<List<double>> embed(String text) async => [0, 1];
  @override
  Future<void> close() async {}
}

class CountingDocumentEmbedder implements DocumentEmbedder {
  CountingDocumentEmbedder(this.tokenizer);
  final UnigramTokenizer tokenizer;
  int calls = 0;
  @override
  Future<DocumentEmbedding> embedDocument(
    List<String> paragraphs,
    Map<String, List<double>> cached,
  ) async => embedDocumentChunks(
    documentTokenChunks(paragraphs, tokenizer),
    cached,
    (_) {
      calls++;
      return [0.6, 0.8];
    },
  );
  @override
  Future<List<double>> embed(String text) async => [0, 1];
  @override
  Future<void> close() async {}
}

void main() {
  late Directory directory;
  late UnigramTokenizer tokenizer;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('noteez-chunks-');
    final file = File('${directory.path}/tokens.json');
    await file.writeAsString(
      jsonEncode({
        'model': {
          'vocab': [
            ['<s>', 0],
            ['<pad>', 0],
            ['</s>', 0],
            ['<unk>', -10],
            ['▁', -1],
            ['가', -1],
            ['나', -1],
          ],
        },
      }),
    );
    tokenizer = UnigramTokenizer()..load(file.path);
  });
  tearDown(() => directory.delete(recursive: true));

  test('short notes preserve the exact original token IDs and vector', () {
    final inputs = documentTokenChunks(['가가', '나나'], tokenizer);
    expect(inputs.single, tokenizer.encode('passage: 가가 나나'));
    final result = embedDocumentChunks(inputs, {}, (_) => [0.6, 0.8]);
    expect(result.vector, [0.6, 0.8]);
  });

  test('oversized paragraphs retain every token including the ending', () {
    final inputs = documentTokenChunks(['${'가' * 1300}나'], tokenizer);
    expect(inputs.length, greaterThan(2));
    expect(
      inputs.every(
        (ids) => ids.length <= 512 && ids.first == 0 && ids.last == 2,
      ),
      isTrue,
    );
    expect(inputs.expand((ids) => ids).where((id) => id == 5), hasLength(1300));
    expect(inputs.last, contains(6));
  });

  test(
    'only changed paragraphs run inference, including after serialization',
    () {
      final paragraphs = ['가' * 600, '나' * 200];
      var calls = 0;
      List<double> infer(List<int> ids) {
        calls++;
        return [0.6, 0.8];
      }

      final first = embedDocumentChunks(
        documentTokenChunks(paragraphs, tokenizer),
        {},
        infer,
      );
      final cached = DocumentEmbedding.parse(
        jsonDecode(jsonEncode(first.toJson())),
      )!;
      calls = 0;
      final second = embedDocumentChunks(
        documentTokenChunks([paragraphs[0], '나' * 201], tokenizer),
        cached.chunks,
        infer,
      );
      expect(calls, 1);
      expect(second.chunks.length, first.chunks.length);
      expect(
        second.vector.fold<double>(0, (s, v) => s + v * v),
        closeTo(1, 0.00001),
      );
      calls = 0;
      embedDocumentChunks(
        documentTokenChunks(['나' * 201, paragraphs[0]], tokenizer),
        second.chunks,
        infer,
      );
      expect(calls, 0);
    },
  );

  test(
    'duplicate inputs are inferred once and invalid caches are rejected',
    () {
      var calls = 0;
      embedDocumentChunks(
        [
          [0, 5, 2],
          [0, 5, 2],
        ],
        {},
        (_) {
          calls++;
          return [1, 0];
        },
      );
      expect(calls, 1);
      expect(DocumentEmbedding.parse([1, 0]), isNull);
      expect(
        DocumentEmbedding.parse({
          'version': 1,
          'vector': [1, 0],
          'chunks': {
            'a': [1],
          },
        }),
        isNull,
      );
    },
  );

  Sticky note(String id) => Sticky(
    id: id,
    blocks: [TextBlock(id: id, text: id)],
    colorIndex: 0,
    x: 0,
    y: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  test(
    'engine restores chunk cache across restart and only embeds edits',
    () async {
      final model = InstalledModel(
        profile: ModelCatalog.models.first,
        modelPath: 'unused',
        tokenizerPath: 'unused',
      );
      final worker = CountingDocumentEmbedder(tokenizer);
      final engine = ConnectionEngine(embedderFactory: (_) => worker)
        ..selectModel(model);
      final original = note('long').copyWith(
        blocks: [
          TextBlock(id: 'a', text: '가' * 600),
          TextBlock(id: 'b', text: '나' * 200),
        ],
      );
      late String storedHash;
      late String payload;
      engine.onPersist = (_, hash, value) async {
        storedHash = hash;
        payload = value;
      };
      await engine.index(original);
      expect(worker.calls, greaterThan(1));
      await engine.close();
      final restartedWorker = CountingDocumentEmbedder(tokenizer);
      final restarted = ConnectionEngine(
        embedderFactory: (_) => restartedWorker,
      )..selectModel(model);
      restarted.seedStored(original, storedHash, payload);
      await restarted.index(original);
      expect(restartedWorker.calls, 0);
      final edited = original.copyWith(
        blocks: [
          original.blocks.first,
          TextBlock(id: 'b', text: '나' * 201),
        ],
      );
      await restarted.index(edited);
      expect(restartedWorker.calls, 1);
      restarted.selectModel(
        InstalledModel(
          profile: ModelCatalog.models.last,
          modelPath: 'different',
          tokenizerPath: 'unused',
        ),
      );
      await restarted.index(edited);
      expect(restartedWorker.calls, greaterThan(2));
      await restarted.close();
    },
  );

  test(
    'paragraph boundaries affect cache identity without resetting dismissals',
    () {
      final engine = ConnectionEngine();
      final a = note('n').copyWith(
        blocks: [TextBlock(id: 'a', text: '가 나')],
      );
      final b = a.copyWith(
        blocks: [
          TextBlock(id: 'a', text: '가'),
          TextBlock(id: 'b', text: '나'),
        ],
      );
      expect(engine.contentHash(a), engine.contentHash(b));
      expect(engine.embeddingHash(a), isNot(engine.embeddingHash(b)));
    },
  );

  test(
    'search uses the matching ending; stale and deleted caches are invisible',
    () async {
      final engine = ConnectionEngine(embedderFactory: (_) => QueryEmbedder())
        ..selectModel(
          InstalledModel(
            profile: ModelCatalog.models.first,
            modelPath: 'unused',
            tokenizerPath: 'unused',
          ),
        );
      final long = note('long');
      final payload = jsonEncode(
        DocumentEmbedding(
          [0.99, 0.1],
          {
            'start': [1, 0],
            'end': [0, 1],
          },
        ).toJson(),
      );
      engine.seedStored(long, engine.embeddingHash(long), payload);
      engine.seed('competitor', 'hash', [0.6, 0.8]);
      engine.seedStored(note('stale'), 'old hash', payload);
      final results = await engine.rankByQuery('ending');
      expect(results.first.key, 'long');
      expect(results.first.value, 1);
      expect(results.any((r) => r.key == 'stale'), isFalse);
      engine.remove('long');
      expect((await engine.rankByQuery('ending')).map((r) => r.key), [
        'competitor',
      ]);
      await engine.close();
    },
  );
}
