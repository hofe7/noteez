import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show AttributeScope, ChangeSource;
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/models/sticky.dart';

// 줄 맨 앞에서 백스페이스 → 체크박스가 풀려 빈 일반 줄이 되어야 한다(행 삭제 X).
void main() {
  testWidgets('backspace at start of empty checkbox unwraps to a plain line',
      (tester) async {
    final key = GlobalKey<NoteEditorState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteEditor(
          key: key,
          autofocus: true,
          // 윗줄 + 빈 체크박스 줄. (행 병합되면 1개로 줄어든다.)
          initial: const [
            TextBlock(id: '1', text: '윗줄'),
            TodoBlock(id: '2', text: '', checked: false),
          ],
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    // 커서를 둘째 줄(빈 체크박스) 맨 앞에 둔다. ("윗줄\n" = 3글자 → offset 3)
    final start = controller.document.toPlainText().indexOf('\n') + 1;
    controller.updateSelection(
      TextSelection.collapsed(offset: start),
      ChangeSource.local,
    );
    await tester.pump();

    // 백스페이스.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    // 에디터 문서 기준 검증(블록 모델은 후행 빈 줄을 트리밍하므로 doc을 직접 본다):
    // 1) 둘째 줄이 사라지지 않음 — 문서에 개행이 그대로 있어야(2줄 유지).
    expect(controller.document.toPlainText(), '윗줄\n\n',
        reason: '행이 병합/삭제되면 안 됨');
    // 2) 커서 줄(둘째 줄)은 더 이상 체크리스트가 아님(블록 포맷 해제).
    final blockAttrs = controller
        .getSelectionStyle()
        .attributes
        .values
        .where((a) => a.scope == AttributeScope.block);
    expect(blockAttrs, isEmpty, reason: '체크박스가 풀려 일반 빈 줄이어야 함');
  });
}
