import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/models/sticky.dart';

// 체크 토글 시 행 간격이 변하지 않음을 보장하는 회귀 테스트.
// (과거: checked/unchecked가 서로 다른 list 블록이라 체크리스트가 쪼개지며
//  블록 경계 여백 2+2px가 끼어 토글마다 4px씩 튀었음. line-height로 간격을
//  옮기고 블록 상/하 여백을 0으로 해 불변화.)
Widget _host(List<Block> blocks) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240,
          child: SingleChildScrollView(
            child: NoteEditor(initial: blocks, onChanged: (_) {}),
          ),
        ),
      ),
    );

void main() {
  testWidgets('toggling a checkbox does not change row spacing',
      (tester) async {
    final blocks = [
      const TodoBlock(id: 'a', text: '할 일 하나', checked: false),
      const TodoBlock(id: 'b', text: '할 일 둘', checked: false),
      const TodoBlock(id: 'c', text: '할 일 셋', checked: false),
    ];
    await tester.pumpWidget(_host(blocks));
    await tester.pumpAndSettle();

    double height() => tester.getSize(find.byType(NoteEditor)).height;
    final before = height();

    // 첫 체크박스 토글 → 체크리스트가 두 블록으로 쪼개지는 시나리오.
    await tester.tap(find.byType(Icon).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(height(), before, reason: '체크 시 행 높이가 변하면 안 됨');

    // 다시 해제 → 원복.
    await tester.tap(find.byType(Icon).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(height(), before, reason: '해제 시 행 높이가 변하면 안 됨');
  });
}
