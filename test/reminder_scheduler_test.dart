import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/reminder/reminder_scheduler.dart';

void main() {
  // 고정 '현재' = 2026-06-08 12:00.
  final fixed = DateTime(2026, 6, 8, 12);
  DateTime now() => fixed;

  test('과거/현재 시각 → 즉시 발화(catch-up)', () async {
    final fired = <String>[];
    final s = ReminderScheduler(fired.add, now: now);
    s.schedule(
      'a',
      fixed.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    expect(fired, ['a']);
    await Future<void>.delayed(Duration.zero);
    expect(s.isScheduled('a'), isFalse, reason: '완료된 발화는 예약을 남기지 않음');
  });

  test('null → 발화도 예약도 안 함(취소)', () {
    final fired = <String>[];
    final s = ReminderScheduler(fired.add, now: now)
      ..schedule(
        'a',
        fixed.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
    expect(s.isScheduled('a'), isTrue);
    s.schedule('a', null); // 재예약 null = 취소
    expect(s.isScheduled('a'), isFalse);
    expect(fired, isEmpty);
  });

  test('미래 시각 → 지연 후 발화', () async {
    final fired = <String>[];
    // delay = atMillis - now() = 30ms (Timer는 실제 시계로 발화).
    final at = fixed.millisecondsSinceEpoch + 30;
    ReminderScheduler(fired.add, now: now).schedule('a', at);
    expect(fired, isEmpty, reason: '아직 발화 전');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, ['a']);
  });

  test('cancel 하면 미래 발화 안 함', () async {
    final fired = <String>[];
    final s = ReminderScheduler(fired.add, now: now)
      ..schedule('a', fixed.millisecondsSinceEpoch + 30);
    s.cancel('a');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, isEmpty);
  });

  test('재예약은 이전 타이머 대체(중복 발화 없음)', () async {
    final fired = <String>[];
    ReminderScheduler(fired.add, now: now)
      ..schedule('a', fixed.millisecondsSinceEpoch + 30)
      ..schedule('a', fixed.millisecondsSinceEpoch + 50); // 대체
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(fired, ['a'], reason: '한 번만 발화');
  });
  test('async delivery failure retries without an unhandled future', () async {
    var attempts = 0;
    final errors = <Object>[];
    final scheduler = ReminderScheduler(
      (_) async {
        if (++attempts == 1) throw StateError('offline');
      },
      retryDelay: const Duration(milliseconds: 10),
      onError: (error, _) => errors.add(error),
    );
    addTearDown(scheduler.dispose);
    scheduler.schedule('a', 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(attempts, 2);
    expect(errors, hasLength(1));
    expect(scheduler.isScheduled('a'), isFalse);
  });

  test(
    'cancel and replacement invalidate retries of an in-flight delivery',
    () async {
      for (final replace in [false, true]) {
        final gate = Completer<void>();
        var attempts = 0;
        final scheduler = ReminderScheduler((_) {
          attempts++;
          return gate.future;
        }, retryDelay: const Duration(milliseconds: 10));
        addTearDown(scheduler.dispose);
        scheduler.schedule('a', 0);
        scheduler.schedule(
          'a',
          replace
              ? DateTime.now()
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch
              : null,
        );
        gate.completeError(StateError('old delivery'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(attempts, 1);
        expect(scheduler.isScheduled('a'), replace);
      }
    },
  );

  test(
    'wall-clock catch-up fires once while original timer is still pending',
    () async {
      var clock = fixed;
      var attempts = 0;
      final gate = Completer<void>();
      final scheduler = ReminderScheduler((_) {
        attempts++;
        return gate.future;
      }, now: () => clock);
      addTearDown(scheduler.dispose);
      scheduler.schedule(
        'a',
        fixed.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
      clock = fixed.add(const Duration(hours: 2));
      scheduler.checkDue();
      scheduler.checkDue();
      expect(attempts, 1);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.isScheduled('a'), isFalse);
    },
  );
}
