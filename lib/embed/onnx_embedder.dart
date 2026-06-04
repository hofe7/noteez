import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

/// e5-small ONNX 임베더. (Step A: input_ids 를 직접 받음. 토크나이저는 Step B에서.)
class OnnxEmbedder {
  OrtSession? _session;

  void init(String modelPath) {
    OrtEnv.instance.init();
    _session = OrtSession.fromFile(File(modelPath), OrtSessionOptions());
  }

  /// 토큰 id → 384차원 정규화 임베딩 (mean pooling + L2 normalize, e5 방식).
  List<double> embedFromIds(List<int> ids, List<int> mask) {
    final s = _session!;
    final n = ids.length;
    final idT =
        OrtValueTensor.createTensorWithDataList(Int64List.fromList(ids), [1, n]);
    final mT =
        OrtValueTensor.createTensorWithDataList(Int64List.fromList(mask), [1, n]);
    final ttT = OrtValueTensor.createTensorWithDataList(Int64List(n), [1, n]);
    final ro = OrtRunOptions();

    final outs = s.run(ro, {
      'input_ids': idT,
      'attention_mask': mT,
      'token_type_ids': ttT,
    }, s.outputNames);

    final value = (outs[0] as OrtValueTensor).value as List; // [1][seq][dim]
    final seq = value[0] as List;
    final dim = (seq[0] as List).length;

    final pooled = List<double>.filled(dim, 0.0);
    var cnt = 0;
    for (var t = 0; t < seq.length; t++) {
      if (t < mask.length && mask[t] == 0) continue;
      cnt++;
      final row = seq[t] as List;
      for (var d = 0; d < dim; d++) {
        pooled[d] += (row[d] as num).toDouble();
      }
    }
    if (cnt == 0) cnt = 1;
    for (var d = 0; d < dim; d++) {
      pooled[d] /= cnt;
    }
    var norm = 0.0;
    for (final x in pooled) {
      norm += x * x;
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (var d = 0; d < dim; d++) {
        pooled[d] /= norm;
      }
    }

    idT.release();
    mT.release();
    ttT.release();
    ro.release();
    for (final o in outs) {
      o?.release();
    }
    return pooled;
  }
}
