import 'dart:io';
import 'dart:async';
import 'package:noteez/services/recommendation_service.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/model_manager.dart';
import 'package:noteez/models/model_catalog.dart';
import 'package:noteez/models/sticky.dart';

/// Reproducible CPU baseline with synthetic cached vectors. No inference or
/// user library access; results do not measure recommendation quality or FPS.
void main() {
  test(
    'measure reference and grouping calculations for large libraries',
    () async {
      for (final count in [500, 1000]) {
        final engine = ConnectionEngine()
          ..selectModel(
            InstalledModel(
              profile: ModelCatalog.models.first,
              modelPath: 'unused',
              tokenizerPath: 'unused',
            ),
          );
        final notes = [
          for (var i = 0; i < count; i++)
            Sticky(
              id: 'note-$i',
              blocks: [
                TextBlock(
                  id: 'block-$i',
                  text: '프로젝트 ${i % 20} 회의록 배포 일정 점검 지시사항 $i',
                ),
              ],
              colorIndex: 0,
              x: 0,
              y: 0,
              open: false,
              createdAt: DateTime(2026, 9, 1),
              updatedAt: DateTime(2026, 9, 1),
            ),
        ];
        for (var i = 0; i < notes.length; i++) {
          final vector = List<double>.filled(384, 0)..[i % 20] = 1;
          engine.seed(notes[i].id, engine.embeddingHash(notes[i]), vector);
        }
        final watch = Stopwatch()..start();
        final refs = engine.referenceSuggestions(
          notes,
          isLinked: (_, _) => false,
        );
        final referencesMs = watch.elapsedMilliseconds;
        watch.reset();
        final groups = engine.suggestedClusters(notes);
        final groupsMs = watch.elapsedMilliseconds;
        final worker = RecommendationWorker();
        final snapshot = RecommendationInput(
          notes: notes,
          vectors: engine.recommendationVectors,
          modelId: engine.modelId,
        );
        var beats = 0, maxGap = 0, previous = 0;
        final backgroundWatch = Stopwatch()..start();
        final heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
          final elapsed = backgroundWatch.elapsedMilliseconds;
          final gap = elapsed - previous;
          if (gap > maxGap) maxGap = gap;
          previous = elapsed;
          beats++;
        });
        try {
          await worker.run(snapshot);
        } finally {
          heartbeat.cancel();
          worker.close();
        }
        final workerMs = backgroundWatch.elapsedMilliseconds;
        // Structured output can be compared across revisions on the same machine.
        // ignore: avoid_print
        print(
          jsonEncode({
            'notes': count,
            'referencesMs': referencesMs,
            'groupsMs': groupsMs,
            'workerMs': workerMs,
            'mainHeartbeatCount': beats,
            'maxHeartbeatGapMs': maxGap,
            'referenceCount': refs.length,
            'groupCount': groups.length,
          }),
        );
        expect(refs.every((r) => r['a'] != r['b']), isTrue);
        await engine.close();
      }
    },
    skip: Platform.environment['NOTEEZ_LIBRARY_BENCHMARK'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
