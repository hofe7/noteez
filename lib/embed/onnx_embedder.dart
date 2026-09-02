import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

/// e5-small ONNX 임베더. (Step A: input_ids 를 직접 받음. 토크나이저는 Step B에서.)
class OnnxEmbedder {
  OrtSession? _session;

  void init(String modelPath) {
    OrtEnv.instance.init();
    final options = OrtSessionOptions();
    try {
      _session = OrtSession.fromFile(File(modelPath), options);
    } finally {
      options.release();
    }
  }

  void dispose() {
    _session?.release();
    _session = null;
  }

  /// 토큰 id → 384차원 정규화 임베딩 (mean pooling + L2 normalize, e5 방식).
  List<double> embedFromIds(List<int> ids, List<int> mask) {
    if (ids.isEmpty || ids.length != mask.length) {
      throw ArgumentError('토큰과 attention mask 길이가 올바르지 않습니다.');
    }
    if (ids.length > 512) {
      throw ArgumentError('multilingual-e5 입력은 512토큰을 넘을 수 없습니다.');
    }
    final s = _session!;
    final n = ids.length;
    final idT = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(ids),
      [1, n],
    );
    final mT = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(mask),
      [1, n],
    );
    final ttT = OrtValueTensor.createTensorWithDataList(Int64List(n), [1, n]);
    final ro = OrtRunOptions();

    final inputs = <String, OrtValue>{
      'input_ids': idT,
      'attention_mask': mT,
      if (s.inputNames.contains('token_type_ids')) 'token_type_ids': ttT,
    };
    List<OrtValue?>? outs;
    try {
      outs = s.run(ro, inputs, s.outputNames);

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
      return pooled;
    } finally {
      idT.release();
      mT.release();
      ttT.release();
      ro.release();
      if (outs != null) {
        for (final output in outs) {
          output?.release();
        }
      }
    }
  }
}
