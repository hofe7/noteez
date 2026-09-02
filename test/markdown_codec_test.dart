import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/markdown/markdown_codec.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  const codec = NoteMarkdownCodec();

  test('decodes common Markdown into Noteez blocks', () async {
    final blocks = await codec.decode(
      '''---
source: notion
---
# Project plan

- [ ] Draft proposal
- [x] Send review
> quiet note
- ordinary item
[OpenAI](https://openai.com) and [Local](other.md)
![diagram](<assets/diagram one.png>)
''',
      resolveImage: (reference) async =>
          reference.startsWith('assets/') ? '/copied/diagram.png' : null,
    );

    expect(blocks[0], isA<TextBlock>());
    expect(blocks[0].text, 'Project plan');
    expect(blocks[1].text, isEmpty, reason: 'paragraph spacing is preserved');
    expect(blocks[2], isA<TodoBlock>());
    expect((blocks[2] as TodoBlock).checked, isFalse);
    expect((blocks[3] as TodoBlock).checked, isTrue);
    expect(blocks[4].text, '› quiet note');
    expect(blocks[5].text, '• ordinary item');
    expect(blocks[6].text, 'OpenAI (https://openai.com) and Local');
    expect(blocks[7], isA<ImageBlock>());
    expect((blocks[7] as ImageBlock).path, '/copied/diagram.png');
  });

  test('encodes text, todos, and exported images as standard Markdown', () {
    final blocks = <Block>[
      const TextBlock(id: 'text', text: 'Project plan'),
      const TodoBlock(id: 'open', text: 'Draft', checked: false),
      const TodoBlock(id: 'done', text: 'Ship', checked: true),
      const ImageBlock(id: 'image', path: '/original/image.png'),
    ];

    expect(
      codec.encode(
        blocks,
        exportedImagePath: (_) => '_assets/Project plan-1.png',
      ),
      '''Project plan
- [ ] Draft
- [x] Ship
![image](<_assets/Project plan-1.png>)
''',
    );
  });

  test('missing image degrades to readable text', () async {
    final blocks = await codec.decode(
      '![remote](https://example.com/image.png)',
      resolveImage: (_) async => null,
    );

    expect(blocks.single, isA<TextBlock>());
    expect(blocks.single.text, 'remote (https://example.com/image.png)');
  });

  test(
    'extracts document links without polluting generated connections',
    () async {
      final decoded = await codec.decodeDocument('''# Alpha
[Beta](folder/Beta.md)
[[Gamma|shown label]]

<!-- noteez-connections:start -->
## Related notes
- [[Delta]]
<!-- noteez-connections:end -->
''');

      expect(decoded.references.map((r) => (r.target, r.wikiLink)), [
        ('folder/Beta.md', false),
        ('Gamma', true),
        ('Delta', true),
      ]);
      expect(decoded.blocks.map((b) => b.text), [
        'Alpha',
        'Beta',
        'shown label',
      ]);
    },
  );

  test('round-trips Noteez metadata and connection section', () async {
    final created = DateTime.utc(2026, 8, 27, 3, 4);
    final markdown = codec.encode(
      [const TextBlock(id: 'text', text: 'Alpha')],
      metadata: NoteMarkdownMetadata(
        noteezId: 'note-id',
        colorIndex: 3,
        createdAt: created,
        updatedAt: created,
        noteezGroupId: 'group-id',
        noteezGroupName: '업무: "출시"',
      ),
      relatedNoteNames: ['Beta', 'Gamma'],
    );
    final decoded = await codec.decodeDocument(markdown);

    expect(decoded.metadata.noteezId, 'note-id');
    expect(decoded.metadata.colorIndex, 3);
    expect(decoded.metadata.createdAt, created);
    expect(decoded.metadata.noteezGroupId, 'group-id');
    expect(decoded.metadata.noteezGroupName, '업무: "출시"');
    expect(decoded.blocks.map((b) => b.text), ['Alpha']);
    expect(decoded.references.map((r) => r.target), ['Beta', 'Gamma']);
  });
}
