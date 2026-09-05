import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/safe_zip.dart';
import 'package:noteez/markdown/markdown_portability.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('noteez-zip-audit-'),
  );
  tearDown(() => root.delete(recursive: true));
  Future<String> zip(List<ArchiveFile> files) async {
    final archive = Archive();
    for (final f in files) {
      archive.add(f);
    }
    final path = '${root.path}/test.zip';
    await File(path).writeAsBytes(ZipEncoder().encode(archive));
    return path;
  }

  test('rejects parent traversal before writing safe entries', () async {
    final path = await zip([
      ArchiveFile('safe.md', 1, [65]),
      ArchiveFile('../escaped.md', 1, [66]),
    ]);
    await expectLater(
      extractZipSafely(path, '${root.path}/output'),
      throwsFormatException,
    );
    expect(File('${root.path}/output/safe.md').existsSync(), isFalse);
    expect(File('${root.path}/escaped.md').existsSync(), isFalse);
  });
  test(
    'ZIP markdown cannot import an image outside its extraction root',
    () async {
      final secret = File('${root.path}/private.png');
      await secret.writeAsBytes([1, 2, 3]);
      final text = utf8.encode('![private](<${secret.uri}>)');
      final path = await zip([ArchiveFile('note.md', text.length, text)]);
      final batch = await MarkdownPortability(
        importAssetsDirectory: Directory('${root.path}/assets'),
      ).importZipPath(path);
      expect(batch.notes.single.blocks.whereType<ImageBlock>(), isEmpty);
      expect(Directory('${root.path}/assets').existsSync(), isFalse);
    },
  );
}
