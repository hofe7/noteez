import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/automatic_clusters.dart';
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/models/model_catalog.dart';
import 'package:noteez/suggested_clusters.dart';
import 'support/automatic_clusters_v2.dart';

void main() {
  test('frozen Small cosine scores preserve quality across four datasets', () {
    final datasets =
        jsonDecode(
              File(
                'test/fixtures/relevance/small-policy-v3-scores.json',
              ).readAsStringSync(),
            )
            as List;
    final profile = ModelCatalog.byId('multilingual-e5-small-qint8')!;
    const expected = {
      'work-notes': (27, 0),
      'notes': (87, 0),
      'validation': (38, 3),
      'recommendation-holdout': (12, 0),
    };
    for (final data in datasets) {
      final fixture = File('test/fixtures/relevance/${data['fixture']}.json');
      expect(
        sha256.convert(fixture.readAsBytesSync()).toString(),
        data['fixtureSha256'],
      );
      expect(
        data['modelSha256'],
        profile.artifacts.firstWhere((a) => a.localName == 'model.onnx').sha256,
      );
      expect(
        data['tokenizerSha256'],
        profile.artifacts
            .firstWhere((a) => a.localName == 'tokenizer.json')
            .sha256,
      );
      final rows = jsonDecode(fixture.readAsStringSync())['notes'] as List;
      final topics = {for (final row in rows) row['id']: row['topic']};
      final ids = (data['ids'] as List).cast<String>();
      final indices = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      HybridRelevanceResult relevance(String a, String b) {
        var i = indices[a]!;
        var j = indices[b]!;
        if (i > j) {
          final swap = i;
          i = j;
          j = swap;
        }
        final score = (data['scores'][i][j - i - 1] as num).toDouble();
        return HybridRelevanceResult(
          score: 1,
          semanticScore: score,
          lexicalScore: 0,
          reasons: const [],
          sharedKeywords: const [],
        );
      }

      (int, int) pairs(List<SuggestedCluster> groups) {
        var correct = 0;
        var incorrect = 0;
        for (final group in groups) {
          for (var i = 0; i < group.ids.length; i++) {
            for (final b in group.ids.skip(i + 1)) {
              if (topics[group.ids[i]] == topics[b]) {
                correct++;
              } else {
                incorrect++;
              }
            }
          }
        }
        return (correct, incorrect);
      }

      final before = AutomaticClusterEngineV2.build(
        ids,
        relevance,
        modelId: profile.id,
      );
      final after = AutomaticClusterEngine.build(
        ids,
        relevance,
        modelId: profile.id,
      );
      expect(pairs(after), expected[data['fixture']], reason: data['fixture']);
      expect(pairs(after).$2, lessThanOrEqualTo(pairs(before).$2));
      for (final group in before) {
        expect(after.any((g) => g.ids.toSet().containsAll(group.ids)), isTrue);
      }
    }
  });
}
