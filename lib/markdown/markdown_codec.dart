import 'dart:convert';

import '../models/sticky.dart';

typedef ImportedImageResolver = Future<String?> Function(String reference);

class MarkdownReference {
  const MarkdownReference(this.target, {required this.wikiLink});

  final String target;
  final bool wikiLink;
}

class NoteMarkdownMetadata {
  const NoteMarkdownMetadata({
    this.noteezId,
    this.colorIndex,
    this.createdAt,
    this.updatedAt,
    this.noteezGroupId,
    this.noteezGroupName,
  });

  final String? noteezId;
  final int? colorIndex;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? noteezGroupId;
  final String? noteezGroupName;
}

class DecodedNoteMarkdown {
  const DecodedNoteMarkdown({
    required this.blocks,
    required this.references,
    required this.metadata,
  });

  final List<Block> blocks;
  final List<MarkdownReference> references;
  final NoteMarkdownMetadata metadata;
}

/// Noteez의 가벼운 블록 모델과 범용 Markdown 사이의 변환기.
///
/// 완전한 Markdown 렌더러가 아니라 이동성에 필요한 의미만 보존한다:
/// 일반 문단, 제목, 인용, 목록, 체크박스, 링크, 로컬 이미지. Noteez가 아직
/// 표현할 수 없는 서식(굵게/코드 등)은 읽기 좋은 평문으로 평탄화한다.
class NoteMarkdownCodec {
  const NoteMarkdownCodec();

  Future<List<Block>> decode(
    String markdown, {
    ImportedImageResolver? resolveImage,
  }) async =>
      (await decodeDocument(markdown, resolveImage: resolveImage)).blocks;

  Future<DecodedNoteMarkdown> decodeDocument(
    String markdown, {
    ImportedImageResolver? resolveImage,
  }) async {
    final source = markdown.replaceFirst('\ufeff', '').replaceAll('\r\n', '\n');
    final lines = source.split('\n');
    final blocks = <Block>[];
    final references = <MarkdownReference>[];
    final frontMatter = <String, String>{};
    var inFrontMatter =
        lines.isNotEmpty &&
        lines.first.trim() == '---' &&
        lines.skip(1).any((line) => line.trim() == '---');
    var inFence = false;
    var inConnections = false;
    var previousWasBlank = false;

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].replaceAll('\r', '');
      final trimmed = raw.trim();

      if (inFrontMatter) {
        if (i > 0 && trimmed == '---') {
          inFrontMatter = false;
        } else if (i > 0) {
          final colon = raw.indexOf(':');
          if (colon > 0) {
            frontMatter[raw.substring(0, colon).trim().toLowerCase()] =
                _unquote(raw.substring(colon + 1).trim());
          }
        }
        continue;
      }
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inFence = !inFence;
        continue;
      }
      if (!inFence) references.addAll(_referencesIn(raw));
      if (trimmed == '<!-- noteez-connections:start -->') {
        inConnections = true;
        continue;
      }
      if (trimmed == '<!-- noteez-connections:end -->') {
        inConnections = false;
        continue;
      }
      if (inConnections) continue;
      if (trimmed.isEmpty) {
        if (blocks.isNotEmpty && !previousWasBlank) blocks.add(textBlock());
        previousWasBlank = true;
        continue;
      }
      previousWasBlank = false;

      if (!inFence) {
        final task = RegExp(r'^\s*[-*+]\s+\[([ xX])\]\s*(.*)$').firstMatch(raw);
        if (task != null) {
          blocks.add(todoBlock(_plain(task.group(2)!), task.group(1) != ' '));
          continue;
        }

        final image = RegExp(
          r'^\s*!\[([^\]]*)\]\((?:<([^>]+)>|([^\s)]+)(?:\s+["\x27].*["\x27])?)\)\s*$',
        ).firstMatch(raw);
        if (image != null) {
          final reference = image.group(2) ?? image.group(3)!;
          final localPath = await resolveImage?.call(reference);
          if (localPath != null) {
            blocks.add(imageBlock(localPath));
          } else {
            final alt = image.group(1)!.trim();
            blocks.add(
              textBlock(alt.isEmpty ? reference : '$alt ($reference)'),
            );
          }
          continue;
        }

        if (RegExp(r'^\s{0,3}([-*_])(?:\s*\1){2,}\s*$').hasMatch(raw)) {
          continue;
        }
      }

      var text = raw;
      if (!inFence) {
        text = text.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
        text = text.replaceFirst(RegExp(r'^\s*>\s?'), '› ');
        text = text.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ');
        text = _plain(text);
      }
      blocks.add(textBlock(text));
    }

    while (blocks.isNotEmpty &&
        blocks.last is TextBlock &&
        blocks.last.text.isEmpty) {
      blocks.removeLast();
    }
    DateTime? date(String key) => DateTime.tryParse(frontMatter[key] ?? '');
    return DecodedNoteMarkdown(
      blocks: blocks,
      references: references,
      metadata: NoteMarkdownMetadata(
        noteezId: frontMatter['noteez-id'],
        colorIndex: int.tryParse(frontMatter['noteez-color'] ?? ''),
        createdAt: date('noteez-created-at'),
        updatedAt: date('noteez-updated-at'),
        noteezGroupId: frontMatter['noteez-group-id'],
        noteezGroupName: frontMatter['noteez-group'],
      ),
    );
  }

  String encode(
    List<Block> blocks, {
    String? Function(ImageBlock image)? exportedImagePath,
    NoteMarkdownMetadata? metadata,
    Iterable<String> relatedNoteNames = const [],
  }) {
    final lines = <String>[];
    if (metadata != null) {
      lines.addAll([
        '---',
        if (metadata.noteezId != null) 'noteez-id: ${metadata.noteezId}',
        if (metadata.colorIndex != null) 'noteez-color: ${metadata.colorIndex}',
        if (metadata.createdAt != null)
          'noteez-created-at: ${metadata.createdAt!.toIso8601String()}',
        if (metadata.updatedAt != null)
          'noteez-updated-at: ${metadata.updatedAt!.toIso8601String()}',
        if (metadata.noteezGroupId != null)
          'noteez-group-id: ${_yamlString(metadata.noteezGroupId!)}',
        if (metadata.noteezGroupName != null)
          'noteez-group: ${_yamlString(metadata.noteezGroupName!)}',
        '---',
      ]);
    }
    for (final block in blocks) {
      switch (block) {
        case TodoBlock todo:
          lines.add('- [${todo.checked ? 'x' : ' '}] ${todo.text}');
        case ImageBlock image:
          final target = exportedImagePath?.call(image);
          if (target == null) {
            lines.add('_이미지를 찾을 수 없음: ${_basename(image.path)}_');
          } else {
            lines.add('![image](<$target>)');
          }
        case TextBlock text:
          lines.add(text.text);
      }
    }
    final related = relatedNoteNames.toSet().toList()..sort();
    if (related.isNotEmpty) {
      if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
      lines.addAll([
        '<!-- noteez-connections:start -->',
        '## Related notes',
        for (final name in related) '- [[$name]]',
        '<!-- noteez-connections:end -->',
      ]);
    }
    return '${lines.join('\n')}\n';
  }

  List<MarkdownReference> _referencesIn(String line) {
    final references = <MarkdownReference>[];
    for (final match in RegExp(r'\[\[([^\]]+)\]\]').allMatches(line)) {
      final raw = match.group(1)!;
      final target = raw.split('|').first.split('#').first.trim();
      if (target.isNotEmpty) {
        references.add(MarkdownReference(target, wikiLink: true));
      }
    }
    for (final match in RegExp(
      r'\[[^\]]+\]\((?:<([^>]+)>|([^)]+))\)',
    ).allMatches(line)) {
      if (match.start > 0 && line[match.start - 1] == '!') continue;
      final target =
          match.group(1)?.trim() ?? match.group(2)!.trim().split(' ').first;
      final uri = Uri.tryParse(target);
      if (target.startsWith('#') || (uri?.hasScheme ?? false)) continue;
      references.add(MarkdownReference(target, wikiLink: false));
    }
    return references;
  }

  String _unquote(String value) {
    if (value.startsWith('"') && value.endsWith('"')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is String) return decoded;
      } catch (_) {
        // 손으로 쓴 느슨한 YAML 문자열은 아래 단순 처리로 복구한다.
      }
    }
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  String _yamlString(String value) => jsonEncode(value);

  String _plain(String value) {
    var text = value;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    text = text.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\((?:<([^>]+)>|([^)]+))\)'),
      (m) => m.group(1)!.isEmpty ? (m.group(2) ?? m.group(3)!) : m.group(1)!,
    );
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((?:<([^>]+)>|([^)]+))\)'),
      (m) {
        final label = m.group(1)!;
        final target = (m.group(2) ?? m.group(3)!).trim();
        return RegExp(
              r'^(https?|mailto):',
              caseSensitive: false,
            ).hasMatch(target)
            ? '$label ($target)'
            : label;
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
      (m) => m.group(2) ?? m.group(1)!,
    );
    for (final pattern in <RegExp>[
      RegExp(r'\*\*(.+?)\*\*'),
      RegExp(r'__(.+?)__'),
      RegExp(r'~~(.+?)~~'),
      RegExp(r'`(.+?)`'),
      RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'),
      RegExp(r'(?<!_)_([^_]+)_(?!_)'),
    ]) {
      text = text.replaceAllMapped(pattern, (m) => m.group(1)!);
    }
    return text.replaceAllMapped(
      RegExp(r'\\([\\`*{}\[\]()#+\-.!_>])'),
      (m) => m.group(1)!,
    );
  }

  String _basename(String value) {
    final normalized = value.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }
}
