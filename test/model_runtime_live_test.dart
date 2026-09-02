import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/embed/onnx_embedder.dart';
import 'package:noteez/embed/unigram_tokenizer.dart';
import 'package:noteez/model_manager.dart';
import 'package:noteez/models/model_catalog.dart';

void main() {
  test(
    'downloaded E5 model embeds a note longer than its position limit',
    () async {
      final support = await Directory.systemTemp.createTemp(
        'noteez-live-model-runtime-',
      );
      final manager = ModelManager(
        supportDirectory: () async => support,
        catalog: [ModelCatalog.models.first],
      );
      final embedder = OnnxEmbedder();
      try {
        await manager.initialize();
        await manager.downloadAndSelect(ModelCatalog.models.first.id);
        final installed = manager.selectedModel!;
        final tokenizer = UnigramTokenizer()..load(installed.tokenizerPath);
        final ids = tokenizer.encode(List.filled(2000, '아주 긴 메모').join(' '));

        expect(ids, hasLength(UnigramTokenizer.defaultMaxTokens));
        embedder.init(installed.modelPath);
        final vector = embedder.embedFromIds(
          ids,
          List<int>.filled(ids.length, 1),
        );
        expect(vector, hasLength(installed.profile.dimensions));
      } finally {
        embedder.dispose();
        await support.delete(recursive: true);
      }
    },
    skip: Platform.environment['RUN_MODEL_LIVE_TESTS'] != '1'
        ? 'Set RUN_MODEL_LIVE_TESTS=1 to download and execute the model.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
