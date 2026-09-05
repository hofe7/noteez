import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/automatic_clusters.dart';
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/suggested_clusters.dart';
import 'package:noteez/model_manager.dart';
import 'package:noteez/models/model_catalog.dart';
import 'package:noteez/models/sticky.dart';

import 'support/automatic_clusters_v2.dart';

void main() {
  test(
    'evaluate grouping on labeled synthetic multilingual notes',
    () async {
      final fixture = File(
        Platform.environment['NOTEEZ_EVAL_FIXTURE'] ??
            'test/fixtures/relevance/notes.json',
      );
      final fixtureHash = sha256
          .convert(await fixture.readAsBytes())
          .toString();
      final data =
          jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
      final rows = (data['notes'] as List).cast<Map<String, dynamic>>();
      final topics = {
        for (final row in rows) row['id'] as String: row['topic'] as String,
      };
      final notes = [
        for (final row in rows)
          Sticky(
            id: row['id'] as String,
            blocks: row['blocks'] is List
                ? (row['blocks'] as List)
                      .map((b) => Block.fromJson(b as Map<String, dynamic>))
                      .toList()
                : [
                    TextBlock(
                      id: row['id'] as String,
                      text: row['text'] as String,
                    ),
                  ],
            colorIndex: 0,
            x: 0,
            y: 0,
            createdAt: DateTime.utc(
              2026,
              1,
              1,
            ).add(Duration(days: row['dayOffset'] as int)),
            updatedAt: DateTime.utc(
              2026,
              1,
              1,
            ).add(Duration(days: row['dayOffset'] as int)),
          ),
      ];
      expect(notes.length, greaterThanOrEqualTo(40));
      expect(topics.length, notes.length);
      expect(topics.values.toSet().length, greaterThanOrEqualTo(10));
      final groups = <String, List<String>>{};
      for (final row in rows.where((row) => row['role'] == 'anchor')) {
        groups
            .putIfAbsent(row['topic'] as String, () => [])
            .add(row['id'] as String);
      }
      expect(groups.values.every((ids) => ids.length == 2), isTrue);

      final engine = ConnectionEngine();
      var modelPath = Platform.environment['NOTEEZ_TEST_MODEL_PATH'];
      var tokenizerPath = Platform.environment['NOTEEZ_TEST_TOKENIZER_PATH'];
      final catalogId = Platform.environment['NOTEEZ_EVAL_CATALOG_MODEL'];
      Directory? temporaryModels;
      ModelManager? manager;
      String? modelHash;
      String? tokenizerHash;
      final vectors = <String, List<double>>{};
      engine.onPersist = (id, _, vector) async {
        vectors[id] =
            ((jsonDecode(vector) is List
                        ? jsonDecode(vector)
                        : (jsonDecode(vector) as Map)['vector'])
                    as List)
                .cast<num>()
                .map((x) => x.toDouble())
                .toList();
      };
      final cachePath = Platform.environment['NOTEEZ_EVAL_VECTOR_CACHE'];
      bool cached = false;
      try {
        if (catalogId != null) {
          final profile = ModelCatalog.byId(catalogId);
          if (profile == null) {
            throw ArgumentError('Unknown catalog model: $catalogId');
          }
          final expectedModelHash = profile.artifacts
              .firstWhere((a) => a.localName == 'model.onnx')
              .sha256;
          final expectedTokenizerHash = profile.artifacts
              .firstWhere((a) => a.localName == 'tokenizer.json')
              .sha256;
          if (cachePath != null && File(cachePath).existsSync()) {
            final cache =
                jsonDecode(await File(cachePath).readAsString())
                    as Map<String, dynamic>;
            if (cache['embeddingPolicyVersion'] == 1 &&
                cache['fixtureSha256'] == fixtureHash &&
                cache['modelSha256'] == expectedModelHash &&
                cache['tokenizerSha256'] == expectedTokenizerHash) {
              final stored = cache['vectors'] as Map<String, dynamic>;
              for (final note in notes) {
                final vector = (stored[note.id] as List)
                    .cast<num>()
                    .map((x) => x.toDouble())
                    .toList();
                expect(vector.length, profile.dimensions);
                expect(vector.every((x) => x.isFinite), isTrue);
                expect(
                  vector.fold<double>(0, (s, x) => s + x * x),
                  closeTo(1, 0.001),
                );
                vectors[note.id] = vector;
              }
              modelHash = expectedModelHash;
              tokenizerHash = expectedTokenizerHash;
              engine.selectModel(
                InstalledModel(
                  profile: profile,
                  modelPath: 'evaluation-cache',
                  tokenizerPath: 'evaluation-cache',
                ),
              );
              for (final note in notes) {
                engine.seed(
                  note.id,
                  engine.embeddingHash(note),
                  vectors[note.id]!,
                );
              }
              cached = true;
            }
          }
          if (!cached && modelPath != null && tokenizerPath != null) {
            expect(
              (await sha256.bind(File(modelPath).openRead()).first).toString(),
              expectedModelHash,
            );
            expect(
              (await sha256.bind(File(tokenizerPath).openRead()).first)
                  .toString(),
              expectedTokenizerHash,
            );
          }
          if (!cached && (modelPath == null || tokenizerPath == null)) {
            final directory = await Directory.systemTemp.createTemp(
              'noteez-evaluation-',
            );
            temporaryModels = directory;
            manager = ModelManager(
              supportDirectory: () async => directory,
              catalog: [profile],
            );
            await manager.initialize();
            await manager.downloadAndSelect(catalogId);
            final installed = manager.selectedModel;
            if (installed == null) {
              throw StateError(
                'Model download or verification failed: ${manager.toJson()['error']}',
              );
            }
            modelPath = installed.modelPath;
            tokenizerPath = installed.tokenizerPath;
          }
        }
        if (!cached && modelPath != null && tokenizerPath != null) {
          modelHash = (await sha256.bind(File(modelPath).openRead()).first)
              .toString();
          tokenizerHash =
              (await sha256.bind(File(tokenizerPath).openRead()).first)
                  .toString();
          engine.selectModel(
            InstalledModel(
              profile:
                  ModelCatalog.byId(catalogId) ?? ModelCatalog.models.first,
              modelPath: modelPath,
              tokenizerPath: tokenizerPath,
            ),
          );
          await engine.warmup(notes);
          expect(engine.ready, isTrue);
        }
        if (cachePath != null && !cached && vectors.isNotEmpty) {
          final cacheFile = File(cachePath);
          await cacheFile.parent.create(recursive: true);
          await cacheFile.writeAsString(
            jsonEncode({
              'embeddingPolicyVersion': 1,
              'fixtureSha256': fixtureHash,
              'modelSha256': modelHash,
              'tokenizerSha256': tokenizerHash,
              'vectors': vectors,
            }),
          );
        }
        final timer = Stopwatch()..start();
        final clusters = engine.suggestedClusters(notes);
        final additions = engine.groupSuggestions(notes, groups);
        timer.stop();
        var expectedPairs = 0;
        for (var i = 0; i < notes.length; i++) {
          for (var j = i + 1; j < notes.length; j++) {
            if (topics[notes[i].id] == topics[notes[j].id]) expectedPairs++;
          }
        }
        Map<String, dynamic> pairMetrics(List<SuggestedCluster> groups) {
          var correct = 0;
          var incorrect = 0;
          for (final group in groups) {
            for (var i = 0; i < group.ids.length; i++) {
              for (var j = i + 1; j < group.ids.length; j++) {
                if (topics[group.ids[i]] == topics[group.ids[j]]) {
                  correct++;
                } else {
                  incorrect++;
                }
              }
            }
          }
          return {
            'correct': correct,
            'incorrect': incorrect,
            'expected': expectedPairs,
            'precision': correct + incorrect == 0
                ? null
                : correct / (correct + incorrect),
            'recall': correct / expectedPairs,
          };
        }

        // Reproduce the previous grouping rule using the exact same vectors.
        // Keep these cutoffs fixed; this is the v1 comparison, not a tuning knob.
        final features = {
          for (final note in notes) note.id: HybridRelevance.prepare(note),
        };
        final baseline = SuggestedClusterEngine.build(
          notes.map((note) => note.id),
          (a, b) {
            final av = vectors[a];
            final bv = vectors[b];
            double? cosine;
            if (av != null && bv != null) {
              cosine = 0;
              for (var i = 0; i < av.length; i++) {
                cosine = cosine! + av[i] * bv[i];
              }
            }
            return HybridRelevance.evaluatePrepared(
              features[a]!,
              features[b]!,
              semanticScore: cosine,
            ).score;
          },
          pairThreshold: 0.62,
          minimumCrossScore: 0.50,
        );
        final previous = AutomaticClusterEngineV2.build(
          notes.map((note) => note.id),
          (a, b) {
            final av = vectors[a];
            final bv = vectors[b];
            double? cosine;
            if (av != null && bv != null) {
              cosine = 0;
              for (var i = 0; i < av.length; i++) {
                cosine = cosine! + av[i] * bv[i];
              }
            }
            return HybridRelevance.evaluatePrepared(
              features[a]!,
              features[b]!,
              semanticScore: cosine,
            );
          },
          modelId: catalogId,
        );
        final correctAdditions = additions
            .where((s) => topics[s.noteId] == s.groupId)
            .length;
        final additionTargets = rows
            .where((row) => row['role'] == 'candidate')
            .length;
        double? ratio(int numerator, int denominator) =>
            denominator == 0 ? null : numerator / denominator;
        final report = {
          'embeddingPolicyVersion': 1,
          'groupingPolicyVersion': AutomaticClusterEngine.policyVersion,
          'fixtureVersion': data['version'],
          'fixtureSplit': data['split'] ?? 'development',
          'fixtureSha256': sha256
              .convert(await fixture.readAsBytes())
              .toString(),
          'mode':
              catalogId ?? (modelHash == null ? 'keyword-only' : 'local-model'),
          'modelSha256': ?modelHash,
          'tokenizerSha256': ?tokenizerHash,
          'notes': notes.length,
          'clusters': clusters.length,
          'predictedClusters': [for (final cluster in clusters) cluster.ids],
          'inferenceSource': cached
              ? 'matching-vector-cache'
              : (vectors.isEmpty ? 'none' : 'onnx'),
          'clusterPairs': pairMetrics(clusters),
          'baselineClusterPairs': pairMetrics(baseline),
          'previousPolicyClusterPairs': pairMetrics(previous),
          'previousPolicyClusters': [for (final group in previous) group.ids],
          'groupAdditions': {
            'suggested': additions.length,
            'correct': correctAdditions,
            'expected': additionTargets,
            'precision': ratio(correctAdditions, additions.length),
            'recall': ratio(correctAdditions, additionTargets),
            'mistakes': [
              for (final s in additions)
                if (topics[s.noteId] != s.groupId)
                  {
                    'noteId': s.noteId,
                    'expectedGroup': topics[s.noteId],
                    'suggestedGroup': s.groupId,
                  },
            ],
          },
          'groupingElapsedMs': timer.elapsedMilliseconds,
        };
        // Quality is reported, not silently defined as "whatever passes". Set
        // release thresholds only after reviewing more independently labeled data.
        final encoded = const JsonEncoder.withIndent('  ').convert(report);
        // ignore: avoid_print
        print(encoded);
        final output = Platform.environment['NOTEEZ_EVAL_REPORT'];
        if (output != null) await File(output).writeAsString('$encoded\n');
      } finally {
        await engine.close();
        manager?.dispose();
        if (temporaryModels != null) {
          await temporaryModels.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
