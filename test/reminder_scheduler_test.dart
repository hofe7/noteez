import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/reminder/reminder_scheduler.dart';

void main() {
  // 고정 '현재' = 2026-06-08 12:00.
  final fixed = DateTime(2026, 6, 8, 12);
  DateTime now() => fixed;

  test('과거/현재 시각 → 즉시 발화(catch-up)', () {
    final fired = <String>[];
    final s = ReminderScheduler(fired.add, now: now);
    s.schedule('a', fixed.subtract(const Duration(hours: 1)).millisecondsSinceEpoch);
    expect(fired, ['a']);
    expect(s.isScheduled('a'), isFalse, reason: '즉시 발화는 타이머 안 남김');
  });

  test('null → 발화도 예약도 안 함(취소)', () {
    final fired = <String>[];
    final s = ReminderScheduler(fired.add, now: now)
      ..schedule('a', fixed.add(const Duration(hours: 1)).millisecondsSinceEpoch);
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
}
