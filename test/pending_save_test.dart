import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/pending_save.dart';

void main() {
  test('closing immediately flushes the latest debounced edit', () async {
    final written = <String>[];
    final saves = PendingSave<String>(
      write: (text) async => written.add(text),
      onError: (_) {},
    );
    addTearDown(saves.dispose);
    saves.schedule('first');
    saves.schedule('latest');
    await saves.flush();
    expect(written, ['latest']);
  });

  test('flush waits for in-flight and later edits in order', () async {
    final gate = Completer<void>();
    final written = <String>[];
    final saves = PendingSave<String>(
      write: (text) async {
        if (text == 'first') await gate.future;
        written.add(text);
      },
      onError: (_) {},
    );
    addTearDown(saves.dispose);
    saves.schedule('first');
    final first = saves.flush();
    saves.schedule('latest');
    final closing = saves.flush();
    expect(written, isEmpty);
    gate.complete();
    await Future.wait([first, closing]);
    expect(written, ['first', 'latest']);
  });

  test('failed close retains content for retry', () async {
    var fail = true;
    final written = <String>[];
    final saves = PendingSave<String>(
      write: (text) async {
        if (fail) throw StateError('disk unavailable');
        written.add(text);
      },
      onError: (_) {},
    );
    addTearDown(saves.dispose);
    saves.schedule('important');
    await expectLater(saves.flush(), throwsStateError);
    fail = false;
    await saves.flush();
    expect(written, ['important']);
  });

  testWidgets('background save failures are reported and can be retried', (
    tester,
  ) async {
    final errors = <Object>[];
    var fail = true;
    final saves = PendingSave<String>(
      write: (_) async {
        if (fail) throw StateError('disk full');
      },
      onError: errors.add,
    );
    addTearDown(saves.dispose);
    saves.schedule('draft');
    await tester.pump(const Duration(milliseconds: 301));
    expect(errors, hasLength(1));
    fail = false;
    await saves.flush();
  });
}
