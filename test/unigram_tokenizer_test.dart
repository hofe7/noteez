import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/embed/unigram_tokenizer.dart';

void main() {
  late Directory temporary;
  late UnigramTokenizer tokenizer;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('noteez-tokenizer-test-');
    final file = File('${temporary.path}/tokenizer.json');
    await file.writeAsString(
      jsonEncode({
        'model': {
          'vocab': [
            ['<s>', 0.0],
            ['<pad>', 0.0],
            ['</s>', 0.0],
            ['<unk>', -10.0],
            ['▁', -1.0],
            ['가', -1.0],
          ],
        },
      }),
    );
    tokenizer = UnigramTokenizer()..load(file.path);
  });

  tearDown(() => temporary.delete(recursive: true));

  test('truncates long input while preserving BOS and EOS', () {
    final ids = tokenizer.encode(List.filled(700, '가').join());

    expect(ids, hasLength(UnigramTokenizer.defaultMaxTokens));
    expect(ids.first, UnigramTokenizer.bos);
    expect(ids.last, UnigramTokenizer.eos);
  });

  test('supports a smaller explicit token budget', () {
    final ids = tokenizer.encode('가가가가가가가가가가', maxTokens: 8);

    expect(ids, hasLength(8));
    expect(ids.first, UnigramTokenizer.bos);
    expect(ids.last, UnigramTokenizer.eos);
  });
}
