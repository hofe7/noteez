import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  testWidgets('completed todo keeps id and completion time after split/edit', (
    tester,
  ) async {
    List<Block> out = const [];
    final key = GlobalKey<NoteEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            key: key,
            initial: const [
              TodoBlock(
                id: 'stable',
                text: '완료한 일',
                checked: true,
                completedAt: 10,
              ),
            ],
            onChanged: (blocks) => out = blocks,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    final end = controller.document.toPlainText().indexOf('\n');
    controller.replaceText(
      end,
      0,
      '\n',
      TextSelection.collapsed(offset: end + 1),
    );
    await tester.pump();

    expect(out, hasLength(2));
    expect(out.first.id, 'stable');
    expect((out.first as TodoBlock).completedAt, 10);

    controller.replaceText(
      0,
      0,
      '수정 ',
      const TextSelection.collapsed(offset: 3),
    );
    await tester.pump();

    expect(out.first.id, 'stable');
    expect(out.first.text, '수정 완료한 일');
    expect((out.first as TodoBlock).completedAt, 10);
  });
}
