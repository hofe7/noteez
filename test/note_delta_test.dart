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
  });

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
