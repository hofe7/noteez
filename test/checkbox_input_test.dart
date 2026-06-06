import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  testWidgets('"[]" + space turns the line into an unchecked todo',
      (tester) async {
    List<Block>? out;
    final key = GlobalKey<NoteEditorState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteEditor(
          key: key,
          initial: [const TextBlock(id: '1', text: '')],
          onChanged: (b) => out = b,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    // 줄에 "[]" 입력 상태를 만든 뒤 단축 핸들러 실행(스페이스 입력 시점과 동일).
    controller.replaceText(0, 0, '[]', const TextSelection.collapsed(offset: 2));
    await tester.pump();

    final line = controller.document.queryChild(0).node as dynamic;
    final node = line.first; // QuillText "[]"
    noteSpaceShortcuts.first.handler(node, controller);
    await tester.pumpAndSettle();

    expect(out, isNotNull);
    expect(out!.length, 1);
    expect(out!.first, isA<TodoBlock>());
    expect((out!.first as TodoBlock).checked, isFalse);
    expect((out!.first as TodoBlock).text, '');
  });
}
