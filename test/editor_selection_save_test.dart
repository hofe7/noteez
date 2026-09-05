import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show ChangeSource;
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  testWidgets('selection changes do not save or change content timestamps', (
    tester,
  ) async {
    var changes = 0;
    final key = GlobalKey<NoteEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            key: key,
            initial: [textBlock('unchanged memo')],
            onChanged: (_) => changes++,
          ),
        ),
      ),
    );
    key.currentState!.controller.updateSelection(
      const TextSelection.collapsed(offset: 4),
      ChangeSource.local,
    );
    await tester.pump();
    expect(changes, 0);
    key.currentState!.controller.replaceText(4, 0, ' edited', null);
    await tester.pump();
    expect(changes, greaterThan(0));
  });
}
