import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/huggingface_model_search.dart';

void main() {
  test(
    'live Hugging Face API returns an installable official profile',
    () async {
      final result = await HuggingFaceModelSearch().search('multilingual-e5');

      expect(result.models, isNotEmpty);
      expect(
        result.models.map((model) => model.repository),
        contains('intfloat/multilingual-e5-small'),
      );
    },
    skip: Platform.environment['RUN_HF_LIVE_TESTS'] != '1'
        ? 'Set RUN_HF_LIVE_TESTS=1 to call the live API.'
        : false,
  );
}
