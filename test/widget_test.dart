import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/report.dart';

void main() {
  test('Sticky JSON round-trip (text + todo blocks)', () {
    final s = makeSticky(
      x: 10,
      y: 20,
      colorIndex: 1,
      blocks: [textBlock('hi'), todoBlock('do it', true)],
    );

    final back = Sticky.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

    expect(back.id, s.id);
    expect(back.x, 10);
    expect(back.y, 20);
    expect(back.colorIndex, 1);
    expect(back.blocks.length, 2);
    expect(back.blocks[0], isA<TextBlock>());
    expect(back.blocks[0].text, 'hi');
    expect(back.blocks[1], isA<TodoBlock>());
    expect((back.blocks[1] as TodoBlock).checked, true);
  });

  test('buildReport groups completed (in-window) and open todos', () {
    final now = DateTime(2026, 6, 4, 12);
    final recent = now.subtract(const Duration(days: 2));
    final old = now.subtract(const Duration(days: 40));

    final s = Sticky(
      id: 's1',
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: recent,
      updatedAt: recent,
      blocks: [
        TextBlock(id: 't', text: '고객사 A'),
        TodoBlock(
            id: 'c1',
            text: '견적 보내기',
            checked: true,
            completedAt: recent.millisecondsSinceEpoch),
        TodoBlock(
            id: 'c2',
            text: '오래된 완료',
            checked: true,
            completedAt: old.millisecondsSinceEpoch),
        TodoBlock(id: 'o1', text: '옵션 정리'),
      ],
    );

    final r = buildReport([s], now);
    final weekDone = r.week.completed.map((c) => c.text);
    final monthDone = r.month.completed.map((c) => c.text);

    // 이번 주: 최근 완료만, 오래된 완료 제외
    expect(weekDone, contains('견적 보내기'));
    expect(weekDone, isNot(contains('오래된 완료')));
    expect(r.week.open, contains('옵션 정리'));
    expect(r.week.activeStickies, 1);

    // 이번 달: 오래된 완료(40일 전)는 30일 밖이라 여전히 제외
    expect(monthDone, contains('견적 보내기'));
    expect(monthDone, isNot(contains('오래된 완료')));
  });

  test('체크됐지만 completedAt 없는 todo는 updatedAt 폴백으로 잡힌다 (시드 버그)', () {
    final now = DateTime(2026, 6, 4, 12);
    final recent = now.subtract(const Duration(days: 1));

    final s = Sticky(
      id: 'seed',
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: recent,
      updatedAt: recent,
      blocks: [
        // 시드처럼 처음부터 checked=true, completedAt 없음
        const TodoBlock(id: 'q', text: '견적서 보내기', checked: true),
      ],
    );

    final r = buildReport([s], now);
    expect(r.week.completed.map((c) => c.text), contains('견적서 보내기'));
  });
}
