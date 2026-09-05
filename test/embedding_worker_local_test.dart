import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/embed/embedding_worker.dart';

void main() {
  final model = Platform.environment['NOTEEZ_TEST_MODEL_PATH'];
  final tokenizer = Platform.environment['NOTEEZ_TEST_TOKENIZER_PATH'];
  test(
    'native worker runs off the caller isolate and closes cleanly',
    () async {
      final worker = EmbeddingWorker(model!, tokenizer!);
      var ticks = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 5),
        (_) => ticks++,
      );
      try {
        final first = await worker.embed('passage: 고객사 미팅에서 캐시 개선 논의');
        final second = await worker.embed('passage: 고객사 미팅에서 캐시 개선 논의');
        expect(first.length, greaterThan(0));
        expect(first.every((value) => value.isFinite), isTrue);
        expect(second, first);
        final short = await worker.embedDocument(['고객사 미팅에서 캐시 개선 논의'], {});
        expect(short.vector, first);
        final ending = '텃밭의 토마토 모종에 물을 주고 수확 시기를 기록';
        final long = await worker.embedDocument([
          List.filled(180, '서버 배포와 캐시 성능 점검').join(' '),
          ending,
        ], {});
        expect(long.chunks.length, greaterThan(1));
        final endingVector = await worker.embed('passage: $ending');
        expect(long.chunks.values, contains(equals(endingVector)));
        final query = await worker.embed('query: 토마토 모종 물주기');
        double similarity(List<double> v) => List.generate(
          v.length,
          (i) => v[i] * query[i],
        ).reduce((a, b) => a + b);
        expect(
          similarity(endingVector),
          greaterThan(similarity(long.chunks.values.first)),
        );
        final restored = await worker.embedDocument([
          List.filled(180, '서버 배포와 캐시 성능 점검').join(' '),
          ending,
        ], long.chunks);
        expect(restored.toJson(), long.toJson());
        expect(
          first.fold<double>(0, (sum, v) => sum + v * v),
          closeTo(1, 0.001),
        );
        expect(ticks, greaterThan(0));
      } finally {
        heartbeat.cancel();
        await worker.close();
      }
      await expectLater(worker.embed('query: 메모'), throwsStateError);
    },
    skip: model == null || tokenizer == null
        ? 'Set NOTEEZ_TEST_MODEL_PATH and NOTEEZ_TEST_TOKENIZER_PATH to local verified model files.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
