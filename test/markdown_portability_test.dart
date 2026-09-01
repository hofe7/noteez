import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/markdown/markdown_portability.dart';
import 'package:noteez/models/sticky.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('noteez-markdown-test-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('folder import discovers nested Markdown files only', () async {
    final nested = Directory(p.join(temp.path, 'nested'))..createSync();
    File(p.join(temp.path, 'a.md')).writeAsStringSync('# Alpha\n- [ ] One');
    File(p.join(nested.path, 'b.markdown')).writeAsStringSync('Beta');
    File(p.join(temp.path, 'ignore.txt')).writeAsStringSync('Ignore');

    final result = await MarkdownPortability().importFolderPath(temp.path);

    expect(result.failedPaths, isEmpty);
    expect(result.notes, hasLength(2));
    expect(result.notes.map((n) => n.title), ['a', 'b']);
    expect(result.notes.first.blocks.first.text, 'Alpha');
    expect(result.notes.first.blocks.whereType<TodoBlock>(), hasLength(1));
  });

  test(
    'folder import resolves Obsidian wiki and relative Markdown links',
    () async {
      final nested = Directory(p.join(temp.path, 'folder'))..createSync();
      File(
        p.join(temp.path, 'Alpha.md'),
      ).writeAsStringSync('[[Beta]]\n[Gamma](folder/Gamma.md)');
      File(p.join(temp.path, 'Beta.md')).writeAsStringSync('Beta');
      File(p.join(nested.path, 'Gamma.md')).writeAsStringSync('Gamma');

      final result = await MarkdownPortability().importFolderPath(temp.path);

      expect(result.links, hasLength(2));
      final pairs = result.links
          .map(
            (link) => ([
              p.basenameWithoutExtension(link.sourcePath),
              p.basenameWithoutExtension(link.targetPath),
            ]..sort()).join('-'),
          )
          .toSet();
      expect(pairs, {'Alpha-Beta', 'Alpha-Gamma'});
    },
  );

  test('repeated image import reuses one app-owned asset', () async {
    final assets = Directory(p.join(temp.path, 'app-assets'));
    final source = Directory(p.join(temp.path, 'source'))..createSync();
    File(p.join(source.path, 'image.png')).writeAsBytesSync([1, 2, 3, 4]);
    final markdown = File(p.join(source.path, 'note.md'))
      ..writeAsStringSync('![image](image.png)');
    final portability = MarkdownPortability(importAssetsDirectory: assets);

    final first = await portability.importPaths([markdown.path]);
    final second = await portability.importPaths([markdown.path]);

    final firstPath = (first.notes.single.blocks.single as ImageBlock).path;
    final secondPath = (second.notes.single.blocks.single as ImageBlock).path;
    expect(secondPath, firstPath);
    expect(assets.listSync().whereType<File>(), hasLength(1));
  });

  test('export creates unique note files and copies image assets', () async {
    final image = File(p.join(temp.path, 'source image.png'))
      ..writeAsBytesSync([0, 1, 2, 3]);
    final now = DateTime(2026, 8, 27, 14, 5);
    Sticky note(String id, List<Block> blocks) => Sticky(
      id: id,
      blocks: blocks,
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: now,
      updatedAt: now,
    );

    final result = await MarkdownPortability().exportToDirectory(
      [
        note('a', [
          const TextBlock(id: 'a-text', text: 'Same title'),
          ImageBlock(id: 'a-image', path: image.path),
        ]),
        note('b', [const TextBlock(id: 'b-text', text: 'Same title')]),
      ],
      temp.path,
      now: now,
      connections: const {
        'a': {'b'},
        'b': {'a'},
      },
    );

    expect(result.noteCount, 2);
    expect(result.imageCount, 1);
    expect(p.basename(result.directoryPath), 'Noteez Export 2026-08-27 1405');
    final first = File(p.join(result.directoryPath, 'Same title.md'));
    final second = File(p.join(result.directoryPath, 'Same title (2).md'));
    expect(first.existsSync(), isTrue);
    expect(second.existsSync(), isTrue);
    expect(first.readAsStringSync(), contains('_assets/Same title-1.png'));
    expect(first.readAsStringSync(), contains('noteez-id: a'));
    expect(first.readAsStringSync(), contains('[[Same title (2)]]'));
    expect(
      File(
        p.join(result.directoryPath, '_assets', 'Same title-1.png'),
      ).existsSync(),
      isTrue,
    );
  });

  test('Noteez export can be imported with IDs, content, and graph intact', () async {
    final now = DateTime.utc(2026, 8, 27, 8);
    Sticky note(String id, String title) => Sticky(
      id: id,
      blocks: [TextBlock(id: '$id-block', text: title)],
      colorIndex: id == 'a' ? 2 : 4,
      x: 0,
      y: 0,
      createdAt: now,
      updatedAt: now,
    );
    final portability = MarkdownPortability();
    final exported = await portability.exportToDirectory(
      [note('a', 'Alpha'), note('b', 'Beta')],
      temp.path,
      now: now,
      connections: const {
        'a': {'b'},
        'b': {'a'},
      },
    );

    final imported = await portability.importFolderPath(
      exported.directoryPath,
    );

    expect(imported.notes.map((n) => n.metadata.noteezId).toSet(), {'a', 'b'});
    expect(imported.notes.map((n) => n.blocks.first.text).toSet(), {
      'Alpha',
      'Beta',
    });
    expect(imported.links, hasLength(1));
  });

  test(
    'Notion ZIP import extracts Markdown and uses stable source keys',
    () async {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'Workspace/Alpha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.md',
            '# Alpha\n[[Beta bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb]]',
          ),
        )
        ..add(
          ArchiveFile.string(
            'Workspace/Beta bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.md',
            'Beta body',
          ),
        );
      final zip = File(p.join(temp.path, 'notion.zip'))
        ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
      final portability = MarkdownPortability();

      final first = await portability.importZipPath(zip.path);
      final second = await portability.importZipPath(zip.path);

      expect(first.notes, hasLength(2));
      expect(first.notes.map((n) => n.title), ['Alpha', 'Beta']);
      expect(first.links, hasLength(1));
      expect(
        second.notes.map((n) => n.sourceKey),
        first.notes.map((n) => n.sourceKey),
        reason: 'temporary extraction paths must not affect duplicate tracking',
      );
    },
  );
}
