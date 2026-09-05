import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/file_dialog_host.dart';

void main() {
  for (final visible in [false, true]) {
    test(
      'file panel keeps its parent visible and restores visibility=$visible',
      () async {
        final events = <String>[];
        final host = FileDialogHost(
          isVisible: () async => visible,
          show: () async => events.add('show'),
          focus: () async => events.add('focus'),
          hide: () async => events.add('hide'),
        );
        final pending = Completer<String?>();
        final operation = host.run(() {
          events.add('panel');
          expect(host.active, isTrue);
          return pending.future;
        });
        await Future<void>.delayed(Duration.zero);
        expect(events, ['show', 'focus', 'panel']);
        await expectLater(host.run(() async => 'second'), throwsStateError);
        expect(host.active, isTrue);
        pending.complete(null); // Native Cancel.
        expect(await operation, isNull);
        expect(host.active, isFalse);
        expect(events, ['show', 'focus', 'panel', if (!visible) 'hide']);
      },
    );
  }
  test(
    'import errors release the visibility guard and allow a retry',
    () async {
      var hidden = 0;
      final host = FileDialogHost(
        isVisible: () async => false,
        show: () async {},
        focus: () async {},
        hide: () async {
          hidden++;
        },
      );
      await expectLater(
        host.run(() async => throw StateError('bad ZIP')),
        throwsStateError,
      );
      expect(host.active, isFalse);
      expect(hidden, 1);
      expect(await host.run(() async => 50), 50);
      expect(hidden, 2);
    },
  );
}
