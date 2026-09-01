import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_delta.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  test('text + todo round-trip preserves type/checked/text', () {
    final blocks = [
      textBlock('hello'),
      todoBlock('do this', false),
      todoBlock('done', true),
      textBlock('end'),
    ];
    final back = NoteDelta.toBlocks(NoteDelta.fromBlocks(blocks));
    expect(back.length, 4);
    expect(back[0], isA<TextBlock>());
    expect(back[0].text, 'hello');
    expect(back[1], isA<TodoBlock>());
    expect((back[1] as TodoBlock).checked, false);
    expect(back[1].text, 'do this');
    expect((back[2] as TodoBlock).checked, true);
    expect(back[2].text, 'done');
    expect(back[3].text, 'end');
    for (var i = 0; i < blocks.length; i++) {
      expect(back[i].id, blocks[i].id, reason: 'block id must survive editing');
    }
  });

  test('todo completion time survives round-trip and text edits by id', () {
    const completed = 123456;
    final old = [
      const TodoBlock(
        id: 'stable',
        text: '완료 전 문구',
        checked: true,
        completedAt: completed,
      ),
    ];
    final roundTrip = NoteDelta.toBlocks(NoteDelta.fromBlocks(old));
    expect((roundTrip.single as TodoBlock).completedAt, completed);

    final edited = [
      const TodoBlock(id: 'stable', text: '수정된 문구', checked: true),
    ];
    final merged = NoteDelta.mergeMetadata(edited, old, nowMillis: 999999);
    expect((merged.single as TodoBlock).completedAt, completed);
  });

  test('same todo text keeps independent completion times', () {
    final old = [
      const TodoBlock(id: 'a', text: '같은 일', checked: true, completedAt: 10),
      const TodoBlock(id: 'b', text: '같은 일', checked: true, completedAt: 20),
    ];
    final next = [
      const TodoBlock(id: 'a', text: '같은 일 수정', checked: true),
      const TodoBlock(id: 'b', text: '같은 일', checked: true),
    ];
    final merged = NoteDelta.mergeMetadata(next, old, nowMillis: 30);
    expect((merged[0] as TodoBlock).completedAt, 10);
    expect((merged[1] as TodoBlock).completedAt, 20);
  });

  test('splitting a line keeps the old id with its original text', () {
    final old = [
      const TodoBlock(
        id: 'stable',
        text: '완료한 일',
        checked: true,
        completedAt: 10,
      ),
    ];
    // Quill에서 Enter를 끝에 입력하면 기존 newline/id가 빈 뒤쪽 줄로 이동한다.
    final split = [
      const TodoBlock(id: 'new', text: '완료한 일', checked: true),
      const TodoBlock(id: 'stable', text: '', checked: true, completedAt: 10),
    ];
    final identified = NoteDelta.reconcileIdentities(split, old);
    expect(identified[0].id, 'stable');
    expect(identified[1].id, 'new');
    final merged = NoteDelta.mergeMetadata(identified, old, nowMillis: 20);
    expect((merged[0] as TodoBlock).completedAt, 10);
  });

  test(
    'newly checked todo receives completion time and unchecked clears it',
    () {
      final checked = NoteDelta.mergeMetadata(
        [const TodoBlock(id: 'a', text: '일', checked: true)],
        [const TodoBlock(id: 'a', text: '일')],
        nowMillis: 42,
      );
      expect((checked.single as TodoBlock).completedAt, 42);

      final unchecked = NoteDelta.mergeMetadata(
        [const TodoBlock(id: 'a', text: '일')],
        checked,
        nowMillis: 50,
      );
      expect((unchecked.single as TodoBlock).completedAt, isNull);

      final rechecked = NoteDelta.mergeMetadata(
        [const TodoBlock(id: 'a', text: '일', checked: true, completedAt: 42)],
        unchecked,
        nowMillis: 60,
      );
      expect(
        (rechecked.single as TodoBlock).completedAt,
        60,
        reason: 're-checking is a new completion',
      );
    },
  );

  test('image block round-trips without an extra empty line', () {
    final blocks = [textBlock('a'), imageBlock('/x/y.png'), textBlock('b')];
    final back = NoteDelta.toBlocks(NoteDelta.fromBlocks(blocks));
    expect(back.length, 3);
    expect(back[0].text, 'a');
    expect(back[1], isA<ImageBlock>());
    expect((back[1] as ImageBlock).path, '/x/y.png');
    expect(back[2].text, 'b');
  });

  test('empty blocks → single empty text block', () {
    final back = NoteDelta.toBlocks(NoteDelta.fromBlocks([]));
    expect(back.length, 1);
    expect(back[0], isA<TextBlock>());
    expect(back[0].text, '');
  });

  test('trailing empty line is trimmed to one block', () {
    final back = NoteDelta.toBlocks(NoteDelta.fromBlocks([textBlock('only')]));
    expect(back.length, 1);
    expect(back[0].text, 'only');
  });
}
