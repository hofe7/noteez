import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/report.dart';

Sticky _sticky(List<Block> blocks, {required int updatedMs}) => Sticky(
      id: 'id-$updatedMs',
      blocks: blocks,
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
    );

void main() {
  final now = DateTime(2026, 6, 8, 12); // 월요일
  final weekStart = DateTime(2026, 6, 8); // 이번 주 시작(월)
  final beforeWeek = weekStart.subtract(const Duration(days: 3));

  test('완료 todo는 completedAt 기준으로 기간에 들어감', () {
    final s = _sticky([
      TodoBlock(
          id: 't1',
          text: '주중 완료',
          checked: true,
          completedAt: DateTime(2026, 6, 9).millisecondsSinceEpoch),
      TodoBlock(
          id: 't2',
          text: '지난주 완료',
          checked: true,
          completedAt: beforeWeek.millisecondsSinceEpoch),
    ], updatedMs: DateTime(2026, 6, 9).millisecondsSinceEpoch);

    final r = buildReport([s], now);
    final weekTexts = r.week.completed.map((c) => c.text).toList();
    expect(weekTexts, contains('주중 완료'));
    expect(weekTexts, isNot(contains('지난주 완료')),
        reason: '주 시작 이전 완료는 이번 주 보고서에서 제외');
    // 월간엔 둘 다 (6월 1일 이후).
    expect(r.month.completed.length, 2);
  });

  test('completedAt 없는 체크 todo는 sticky.updatedAt 으로 폴백', () {
    // completedAt null + updatedAt 이 주중 → 이번 주 완료로 잡혀야 함 (과거 버그 회귀).
    final s = _sticky([
      const TodoBlock(id: 't', text: '시드 완료', checked: true),
    ], updatedMs: DateTime(2026, 6, 9).millisecondsSinceEpoch);

    final r = buildReport([s], now);
    expect(r.week.completed.map((c) => c.text), contains('시드 완료'));
  });

  test('열린 todo는 open, 빈 텍스트는 무시', () {
    final s = _sticky([
      const TodoBlock(id: 'o', text: '할 일 남음', checked: false),
      const TodoBlock(id: 'e', text: '   ', checked: false), // 빈 → 무시
      const TextBlock(id: 'x', text: '본문은 todo 아님'),
    ], updatedMs: now.millisecondsSinceEpoch);

    final r = buildReport([s], now);
    expect(r.week.open, ['할 일 남음']);
    expect(r.week.completed, isEmpty);
  });

  test('완료 목록은 완료 시각 내림차순', () {
    final s = _sticky([
      TodoBlock(
          id: 'a',
          text: '먼저',
          checked: true,
          completedAt: DateTime(2026, 6, 8).millisecondsSinceEpoch),
      TodoBlock(
          id: 'b',
          text: '나중',
          checked: true,
          completedAt: DateTime(2026, 6, 10).millisecondsSinceEpoch),
    ], updatedMs: DateTime(2026, 6, 10).millisecondsSinceEpoch);

    final r = buildReport([s], now);
    expect(r.month.completed.map((c) => c.text), ['나중', '먼저']);
  });

  test('activeStickies = 기간 내 수정된 스티커 수', () {
    final recent = _sticky([const TextBlock(id: 'r', text: 'a')],
        updatedMs: DateTime(2026, 6, 9).millisecondsSinceEpoch);
    final old = _sticky([const TextBlock(id: 'o', text: 'b')],
        updatedMs: beforeWeek.millisecondsSinceEpoch);
    final r = buildReport([recent, old], now);
    expect(r.week.activeStickies, 1);
    expect(r.month.activeStickies, 2);
  });
}
