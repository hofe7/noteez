import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sticky.dart';
import 'markdown_codec.dart';

const _markdownTypes = <XTypeGroup>[
  XTypeGroup(label: 'Markdown', extensions: ['md', 'markdown']),
];
const _zipTypes = <XTypeGroup>[
  XTypeGroup(label: 'Notion ZIP', extensions: ['zip']),
];

Future<void> _extractZipSafely(String zipPath, String outputPath) async {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input, verify: true);
    var totalBytes = 0;
    for (final entry in archive) {
      if (entry.isFile) totalBytes += entry.size;
    }
    if (archive.length > 20000 || totalBytes > 2 * 1024 * 1024 * 1024) {
      throw const FormatException('ZIP is too large to import safely');
    }
    await extractArchiveToDisk(archive, outputPath);
  } finally {
    await input.close();
  }
}

class ImportedMarkdownNote {
  const ImportedMarkdownNote({
    required this.sourcePath,
    required this.sourceKey,
    required this.sourceHash,
    required this.title,
    required this.blocks,
    required this.references,
    required this.metadata,
  });

  final String sourcePath;
  final String sourceKey;
  final String sourceHash;
  final String title;
  final List<Block> blocks;
  final List<MarkdownReference> references;
  final NoteMarkdownMetadata metadata;
}

class ImportedMarkdownLink {
  const ImportedMarkdownLink(this.sourcePath, this.targetPath);

  final String sourcePath;
  final String targetPath;
}

class MarkdownImportBatch {
  const MarkdownImportBatch(this.notes, this.links, this.failedPaths);

  final List<ImportedMarkdownNote> notes;
  final List<ImportedMarkdownLink> links;
  final List<String> failedPaths;
}

class MarkdownExportResult {
  const MarkdownExportResult({
    required this.directoryPath,
    required this.noteCount,
    required this.imageCount,
  });

  final String directoryPath;
  final int noteCount;
  final int imageCount;
}

/// 네이티브 파일 선택기와 Markdown 변환을 묶은 이동성 계층.
/// DB나 창을 모르므로 추후 Notion export/Obsidian vault 어댑터도 이 결과 타입으로
/// MainController에 전달할 수 있다.
class MarkdownPortability {
  MarkdownPortability({
    NoteMarkdownCodec codec = const NoteMarkdownCodec(),
    Directory? importAssetsDirectory,
  }) : _codec = codec,
       _importAssetsOverride = importAssetsDirectory;

  final NoteMarkdownCodec _codec;
  final Directory? _importAssetsOverride;

  String referenceTitle(MarkdownReference reference) {
    final decoded = _decodeReference(reference.target).replaceAll('\\', '/');
    return p.posix
        .basenameWithoutExtension(decoded)
        .replaceFirst(RegExp(r'\s+[0-9a-f]{32}$', caseSensitive: false), '')
        .trim();
  }

  Future<MarkdownImportBatch?> pickFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: _markdownTypes,
      confirmButtonText: '가져오기',
    );
    if (files.isEmpty) return null;
    return importPaths(files.map((f) => f.path));
  }

  Future<MarkdownImportBatch?> pickFolder() async {
    final root = await getDirectoryPath(confirmButtonText: '폴더 가져오기');
    if (root == null) return null;
    return importFolderPath(root);
  }

  Future<MarkdownImportBatch?> pickNotionZip() async {
    final file = await openFile(
      acceptedTypeGroups: _zipTypes,
      confirmButtonText: 'ZIP 가져오기',
    );
    if (file == null) return null;
    return importZipPath(file.path);
  }

  Future<MarkdownImportBatch> importZipPath(String zipPath) async {
    final temporary = await Directory.systemTemp.createTemp('noteez-notion-');
    final temporaryPath = temporary.path;
    try {
      // 큰 Notion export의 압축 해제가 UI isolate를 막지 않도록 별도 isolate에서.
      await Isolate.run(() => _extractZipSafely(zipPath, temporaryPath));
      return await importFolderPath(
        temporaryPath,
        sourceNamespace: 'zip:${_normalizedPath(zipPath)}',
      );
    } finally {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  }

  Future<MarkdownImportBatch> importFolderPath(
    String root, {
    String? sourceNamespace,
  }) async {
    final files = <String>[];
    await for (final entity in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.md' || ext == '.markdown') files.add(entity.path);
    }
    files.sort();
    return importPaths(
      files,
      sourceRoot: sourceNamespace == null ? null : root,
      sourceNamespace: sourceNamespace,
    );
  }

  Future<MarkdownImportBatch> importPaths(
    Iterable<String> paths, {
    String? sourceRoot,
    String? sourceNamespace,
  }) async {
    final notes = <ImportedMarkdownNote>[];
    final failed = <String>[];
    final copiedImages = <String, String>{};
    Directory? importAssets;

    for (final sourcePath in paths) {
      try {
        final markdown = await File(sourcePath).readAsString();
        final decoded = await _codec.decodeDocument(
          markdown,
          resolveImage: (reference) async {
            final source = _localImagePath(sourcePath, reference);
            if (source == null) return null;
            final sourceFile = File(source);
            if (!await sourceFile.exists()) return null;
            final cached = copiedImages[source];
            if (cached != null) return cached;

            importAssets ??= await _importAssetsDirectory();
            final fingerprint = await _stableFileHash(sourceFile);
            final target = File(
              p.join(
                importAssets!.path,
                '$fingerprint-${_safeFileName(p.basename(source))}',
              ),
            );
            if (!await target.exists()) await sourceFile.copy(target.path);
            copiedImages[source] = target.path;
            return target.path;
          },
        );
        final externalId = decoded.metadata.noteezId?.trim();
        final sourceKey = externalId == null || externalId.isEmpty
            ? _sourceKey(
                sourcePath,
                sourceRoot: sourceRoot,
                sourceNamespace: sourceNamespace,
              )
            : 'noteez:$externalId';
        notes.add(
          ImportedMarkdownNote(
            sourcePath: sourcePath,
            sourceKey: sourceKey,
            sourceHash: _stableHash(markdown),
            title: _titleFromPath(sourcePath),
            blocks: decoded.blocks,
            references: decoded.references,
            metadata: decoded.metadata,
          ),
        );
      } catch (_) {
        failed.add(sourcePath);
      }
    }
    return MarkdownImportBatch(notes, _resolveLinks(notes), failed);
  }

  Future<MarkdownExportResult?> exportAll(
    List<Sticky> stickies, {
    Map<String, Set<String>> connections = const {},
  }) async {
    final selected = await getDirectoryPath(
      confirmButtonText: '여기에 내보내기',
      canCreateDirectories: true,
    );
    if (selected == null) return null;

    return exportToDirectory(stickies, selected, connections: connections);
  }

  Future<MarkdownExportResult> exportToDirectory(
    List<Sticky> stickies,
    String selected, {
    DateTime? now,
    Map<String, Set<String>> connections = const {},
  }) async {
    final exportRoot = await _uniqueDirectory(
      Directory(selected),
      _exportDirectoryName(now ?? DateTime.now()),
    );
    final assets = Directory(p.join(exportRoot.path, '_assets'));
    final usedNames = <String>{};
    final noteNames = <String, String>{};
    var imageCount = 0;

    for (var noteIndex = 0; noteIndex < stickies.length; noteIndex++) {
      final sticky = stickies[noteIndex];
      noteNames[sticky.id] = _uniqueNoteName(
        _safeFileName(sticky.preview, fallback: '메모 ${noteIndex + 1}'),
        usedNames,
      );
    }

    for (var noteIndex = 0; noteIndex < stickies.length; noteIndex++) {
      final sticky = stickies[noteIndex];
      final base = noteNames[sticky.id]!;
      final exportedImages = <String, String>{};
      var imageIndex = 0;
      for (final block in sticky.blocks.whereType<ImageBlock>()) {
        imageIndex++;
        final source = File(block.path);
        if (!await source.exists()) continue;
        if (!await assets.exists()) await assets.create(recursive: true);
        final extension = p.extension(block.path).isEmpty
            ? '.png'
            : p.extension(block.path).toLowerCase();
        final file = await _uniqueFile(assets, '$base-$imageIndex$extension');
        await source.copy(file.path);
        exportedImages[block.id] = p.posix.join(
          '_assets',
          p.basename(file.path),
        );
        imageCount++;
      }

      final markdown = _codec.encode(
        sticky.blocks,
        exportedImagePath: (image) => exportedImages[image.id],
        metadata: NoteMarkdownMetadata(
          noteezId: sticky.id,
          colorIndex: sticky.colorIndex,
          createdAt: sticky.createdAt,
          updatedAt: sticky.updatedAt,
        ),
        relatedNoteNames: (connections[sticky.id] ?? const <String>{})
            .map((id) => noteNames[id])
            .whereType<String>(),
      );
      await File(
        p.join(exportRoot.path, '$base.md'),
      ).writeAsString(markdown, encoding: utf8, flush: true);
    }

    return MarkdownExportResult(
      directoryPath: exportRoot.path,
      noteCount: stickies.length,
      imageCount: imageCount,
    );
  }

  List<ImportedMarkdownLink> _resolveLinks(List<ImportedMarkdownNote> notes) {
    final byPath = <String, ImportedMarkdownNote>{
      for (final note in notes) _normalizedPath(note.sourcePath): note,
    };
    final aliases = <String, List<ImportedMarkdownNote>>{};
    for (final note in notes) {
      for (final alias in <String>{
        note.title.toLowerCase(),
        p.basenameWithoutExtension(note.sourcePath).toLowerCase(),
      }) {
        (aliases[alias] ??= []).add(note);
      }
    }

    final seen = <String>{};
    final links = <ImportedMarkdownLink>[];
    for (final source in notes) {
      for (final reference in source.references) {
        ImportedMarkdownNote? target;
        if (reference.wikiLink) {
          final wanted = _decodeReference(
            reference.target,
          ).replaceAll('\\', '/').toLowerCase();
          final direct = aliases[p.posix.basenameWithoutExtension(wanted)];
          if (direct?.length == 1) target = direct!.single;
          target ??= _uniqueMatch(
            notes.where((note) {
              final withoutExtension = p
                  .withoutExtension(note.sourcePath)
                  .replaceAll('\\', '/')
                  .toLowerCase();
              return withoutExtension.endsWith('/$wanted') ||
                  withoutExtension.endsWith('/${p.withoutExtension(wanted)}');
            }),
          );
        } else {
          final decoded = _decodeReference(reference.target);
          var resolved = _normalizedPath(
            p.join(p.dirname(source.sourcePath), decoded),
          );
          target = byPath[resolved];
          if (target == null && p.extension(resolved).isEmpty) {
            resolved = '$resolved.md';
            target = byPath[resolved];
          }
        }
        if (target == null || target.sourcePath == source.sourcePath) continue;
        final ordered = source.sourcePath.compareTo(target.sourcePath) <= 0
            ? '${source.sourcePath}|${target.sourcePath}'
            : '${target.sourcePath}|${source.sourcePath}';
        if (seen.add(ordered)) {
          links.add(ImportedMarkdownLink(source.sourcePath, target.sourcePath));
        }
      }
    }
    return links;
  }

  ImportedMarkdownNote? _uniqueMatch(Iterable<ImportedMarkdownNote> matches) {
    final list = matches.take(2).toList();
    return list.length == 1 ? list.single : null;
  }

  String _decodeReference(String reference) {
    final withoutAnchor = reference.trim().split('#').first.split('?').first;
    try {
      return Uri.decodeFull(withoutAnchor);
    } catch (_) {
      return withoutAnchor;
    }
  }

  String _normalizedPath(String value) =>
      p.normalize(p.absolute(value)).toLowerCase();

  String _sourceKey(
    String sourcePath, {
    String? sourceRoot,
    String? sourceNamespace,
  }) {
    if (sourceRoot != null && sourceNamespace != null) {
      final relative = p
          .relative(sourcePath, from: sourceRoot)
          .replaceAll('\\', '/')
          .toLowerCase();
      return '$sourceNamespace:$relative';
    }
    return 'file:${_normalizedPath(sourcePath)}';
  }

  String _titleFromPath(String sourcePath) => p
      .basenameWithoutExtension(sourcePath)
      .replaceFirst(RegExp(r'\s+[0-9a-f]{32}$', caseSensitive: false), '')
      .trim();

  String _stableHash(String value) {
    final bytes = utf8.encode(value.replaceAll('\r\n', '\n'));
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${bytes.length}:${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String? _localImagePath(String markdownPath, String rawReference) {
    final reference = rawReference.trim().split('#').first.split('?').first;
    final uri = Uri.tryParse(reference);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'file') return null;
      return p.normalize(uri.toFilePath());
    }
    try {
      return p.normalize(
        p.join(p.dirname(markdownPath), Uri.decodeFull(reference)),
      );
    } catch (_) {
      return p.normalize(p.join(p.dirname(markdownPath), reference));
    }
  }

  Future<Directory> _importAssetsDirectory() async {
    final override = _importAssetsOverride;
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'imports', 'assets'));
    await root.create(recursive: true);
    return root;
  }

  Future<String> _stableFileHash(File file) async {
    var hash = 0x811c9dc5;
    var length = 0;
    await for (final chunk in file.openRead()) {
      length += chunk.length;
      for (final byte in chunk) {
        hash ^= byte;
        hash = (hash * 0x01000193) & 0xffffffff;
      }
    }
    return '$length-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  Future<Directory> _uniqueDirectory(Directory parent, String name) async {
    var candidate = Directory(p.join(parent.path, name));
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = Directory(p.join(parent.path, '$name ($suffix)'));
      suffix++;
    }
    await candidate.create(recursive: true);
    return candidate;
  }

  Future<File> _uniqueFile(Directory directory, String name) async {
    final ext = p.extension(name);
    final stem = p.basenameWithoutExtension(name);
    var candidate = File(p.join(directory.path, name));
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(directory.path, '$stem-$suffix$ext'));
      suffix++;
    }
    return candidate;
  }

  String _uniqueNoteName(String proposed, Set<String> used) {
    var candidate = proposed;
    var suffix = 2;
    while (!used.add(candidate.toLowerCase())) {
      candidate = '$proposed ($suffix)';
      suffix++;
    }
    return candidate;
  }

  String _safeFileName(String value, {String fallback = '메모'}) {
    var safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    safe = safe.replaceAll(RegExp(r'[. ]+$'), '');
    if (safe.isEmpty) safe = fallback;
    if (safe.length > 80) safe = safe.substring(0, 80).trimRight();
    return safe;
  }

  String _exportDirectoryName(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Noteez Export ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}${two(now.minute)}';
  }
}
