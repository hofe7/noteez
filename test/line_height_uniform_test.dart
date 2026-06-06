import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/models/sticky.dart';

// 빈 개행 줄과 값이 있는 줄의 높이가 같아야 한다.
// (과거: 본문 스타일의 leadingDistribution.even 때문에 height>1.0에서 빈 줄의
//  strut 높이가 값 줄보다 커서 "그냥 개행"과 "값 입력 줄"의 높이가 어긋났음.)
void main() {
  testWidgets('empty lines have the same height as filled lines',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240,
          child: SingleChildScrollView(
            child: NoteEditor(
              initial: const [
                TextBlock(id: '1', text: '첫 줄'),
                TextBlock(id: '2', text: ''),
                TextBlock(id: '3', text: '셋째 줄'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final heights = <double>[];
    for (final e in find.byType(RichText).evaluate()) {
      heights.add((e.renderObject as RenderBox).size.height);
    }
    expect(heights.length, greaterThanOrEqualTo(3));
    final first = heights.first;
    for (final h in heights) {
      expect(h, first, reason: '모든 줄(빈 줄 포함) 높이가 같아야 함: $heights');
    }
  });
}
