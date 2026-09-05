import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/date_query.dart';

void main() {
  test('oversized and zero date expressions fall back to keyword search', () {
    final now = DateTime(2026, 9, 5);
    expect(parseDateQuery('999999999999999999999999999일 전', now), isNull);
    expect(parseDateQuery('최근 0일', now), isNull);
    expect(parseDateQuery('최근 999999999999999999999999일', now), isNull);
  });
  // 기준 시각: 2026-06-08 (월요일).
  final now = DateTime(2026, 6, 8, 15, 30);
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('날짜 표현 아니면 null', () {
    expect(parseDateQuery('레디스 구조', now), isNull);
    expect(parseDateQuery('', now), isNull);
    expect(parseDateQuery('회의록', now), isNull);
  });

  test('오늘/어제/그제 — 하루 구간 [start, +1d)', () {
    final t = parseDateQuery('오늘', now)!;
    expect(t.contains(d(2026, 6, 8)), isTrue);
    expect(t.contains(d(2026, 6, 9)), isFalse);
    expect(t.contains(d(2026, 6, 7)), isFalse);

    expect(parseDateQuery('어제', now)!.contains(d(2026, 6, 7)), isTrue);
    expect(parseDateQuery('그제', now)!.contains(d(2026, 6, 6)), isTrue);
  });

  test('이번 주(월~일) / 지난 주', () {
    final wk = parseDateQuery('이번 주', now)!;
    expect(wk.contains(d(2026, 6, 8)), isTrue, reason: '월요일 포함');
    expect(wk.contains(d(2026, 6, 14)), isTrue, reason: '일요일 포함');
    expect(wk.contains(d(2026, 6, 15)), isFalse, reason: '다음 월요일 제외');
    expect(wk.contains(d(2026, 6, 7)), isFalse, reason: '지난 일요일 제외');

    final last = parseDateQuery('지난주', now)!;
    expect(last.contains(d(2026, 6, 1)), isTrue);
    expect(last.contains(d(2026, 6, 7)), isTrue);
    expect(last.contains(d(2026, 6, 8)), isFalse);
  });

  test('이번 달 / 지난 달', () {
    final m = parseDateQuery('이번 달', now)!;
    expect(m.contains(d(2026, 6, 1)), isTrue);
    expect(m.contains(d(2026, 6, 30)), isTrue);
    expect(m.contains(d(2026, 7, 1)), isFalse);

    final prev = parseDateQuery('지난달', now)!;
    expect(prev.contains(d(2026, 5, 1)), isTrue);
    expect(prev.contains(d(2026, 5, 31)), isTrue);
    expect(prev.contains(d(2026, 6, 1)), isFalse);
  });

  test('N일 전', () {
    final t = parseDateQuery('3일 전', now)!;
    expect(t.contains(d(2026, 6, 5)), isTrue);
    expect(t.contains(d(2026, 6, 6)), isFalse);
  });

  test('최근 N일 (오늘 포함 과거 N일)', () {
    final t = parseDateQuery('최근 3일', now)!;
    expect(t.contains(d(2026, 6, 6)), isTrue);
    expect(t.contains(d(2026, 6, 8)), isTrue);
    expect(t.contains(d(2026, 6, 5)), isFalse);
    expect(t.contains(d(2026, 6, 9)), isFalse);
  });

  test('N월 — 미래 달이면 작년', () {
    final june = parseDateQuery('6월', now)!;
    expect(june.contains(d(2026, 6, 1)), isTrue);
    expect(june.contains(d(2026, 7, 1)), isFalse);
    // 12월은 아직 안 옴 → 작년 12월.
    final dec = parseDateQuery('12월', now)!;
    expect(dec.contains(d(2025, 12, 25)), isTrue);
    expect(dec.contains(d(2026, 12, 25)), isFalse);
  });

  test('M월 D일 / ISO / M.D', () {
    expect(parseDateQuery('6월 3일', now)!.contains(d(2026, 6, 3)), isTrue);
    expect(parseDateQuery('2025-01-15', now)!.contains(d(2025, 1, 15)), isTrue);
    expect(parseDateQuery('6/3', now)!.contains(d(2026, 6, 3)), isTrue);
    // 무효 날짜 → null.
    expect(parseDateQuery('2월 30일', now), isNull);
  });

  test('접미사: 이후(start만) / 까지(end만) / 이전', () {
    final after = parseDateQuery('6월 이후', now)!;
    expect(after.start, isNotNull);
    expect(after.end, isNull);
    expect(after.contains(d(2026, 12, 31)), isTrue);
    expect(after.contains(d(2026, 5, 1)), isFalse);

    final until = parseDateQuery('어제 까지', now)!;
    expect(until.end, isNotNull);
    expect(until.contains(d(2020, 1, 1)), isTrue);
  });

  test('범위: A ~ B (양쪽 닫힘, end 포함일의 끝)', () {
    final r = parseDateQuery('6/1 ~ 6/10', now)!;
    expect(r.contains(d(2026, 6, 1)), isTrue);
    expect(r.contains(d(2026, 6, 10)), isTrue);
    expect(r.contains(d(2026, 6, 11)), isFalse);
    expect(r.contains(d(2026, 5, 31)), isFalse);
  });
}
