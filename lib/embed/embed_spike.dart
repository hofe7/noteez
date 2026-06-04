import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'onnx_embedder.dart';
import 'unigram_tokenizer.dart';

// 샌드박스에서 HOME 은 이미 컨테이너(.../Data)로 리매핑됨 → Documents 만 붙이면 됨.
String get _modelDir => '${Platform.environment['HOME']}/Documents';

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

double _cos(List<double> a, List<double> b) {
  var d = 0.0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    d += a[i] * b[i];
  }
  return d;
}

/// Step A: Python이 만든 input_ids 를 그대로 넣어, 임베딩이 레퍼런스와 일치하는지.
/// (토크나이저 불확실성 배제 — 순수 ONNX 런타임 + 풀링 검증)
Future<String> runEmbeddingSpike() async {
  try {
    final emb = OnnxEmbedder();
    emb.init('$_modelDir/e5_int8.onnx');
    final tok = UnigramTokenizer();
    tok.load('$_modelDir/e5_tokenizer.json');

    final fixtures =
        jsonDecode(File('$_modelDir/fixture.json').readAsStringSync()) as List;

    final lines = <String>[];
    for (final f in fixtures) {
      final refIds = (f['ids'] as List).cast<int>();
      final ref =
          (f['emb'] as List).map((e) => (e as num).toDouble()).toList();

      // Step C: Dart 토크나이저 → 임베딩 (전체 파이프라인)
      final myIds = tok.encode(f['text'] as String);
      final idsMatch = _listEq(myIds, refIds);
      final got = emb.embedFromIds(myIds, List<int>.filled(myIds.length, 1));
      final c = _cos(ref, got);

      final line = 'cos=${c.toStringAsFixed(4)} '
          'ids=${idsMatch ? "MATCH" : "${myIds.length}vs${refIds.length}"}  '
          '"${(f['text'] as String)}"';
      debugPrint('NOTEEZ_EMBED_SPIKE: $line');
      if (!idsMatch) {
        debugPrint('NOTEEZ_EMBED_SPIKE:   mine=$myIds');
        debugPrint('NOTEEZ_EMBED_SPIKE:   ref =$refIds');
      }
      lines.add(line);
    }
    return lines.join('\n');
  } catch (e, st) {
    debugPrint('NOTEEZ_EMBED_SPIKE: FAILED $e\n$st');
    return 'FAILED: $e';
  }
}
