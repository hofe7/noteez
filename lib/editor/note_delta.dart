import 'package:flutter_quill/quill_delta.dart';

import '../models/sticky.dart';

/// 기존 블록 모델 ↔ Quill Delta 변환.
///
/// 저장은 Delta 정본으로 가지만, (a) 기존 blocks_json 데이터를 1회 변환해 들여오고,
/// (b) 검색/임베딩/보고는 여전히 블록(평문/구조)로 읽으므로 양방향 변환이 필요하다.
///
/// 매핑:
///   TextBlock  ↔ 일반 줄
///   TodoBlock  ↔ 체크리스트 줄 (line attr `list: checked|unchecked`)
///   ImageBlock ↔ 이미지 임베드 ({'image': path})
class NoteDelta {
  /// 블록들 → Delta. 각 줄은 개행으로 끝나고, 체크리스트는 개행에 line attr을 건다.
  static Delta fromBlocks(List<Block> blocks) {
    final d = Delta();
    for (final b in blocks) {
      switch (b) {
        case ImageBlock img:
          d.insert({'image': img.path});
          d.insert('\n');
        case TodoBlock t:
          _insertLines(d, t.text,
              {'list': t.checked ? 'checked' : 'unchecked'});
        case TextBlock _:
          _insertLines(d, b.text, null);
      }
    }
    if (blocks.isEmpty) d.insert('\n');
    return d;
  }

  // 블록 본문이 여러 줄(블록 내 개행)일 수 있으니 줄마다 개행+attr을 넣는다.
  static void _insertLines(Delta d, String text, Map<String, dynamic>? lineAttr) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.isNotEmpty) d.insert(line);
      d.insert('\n', lineAttr);
    }
  }

  /// Delta → 블록들. 개행의 line attr로 줄 종류를 판정하고, 이미지 임베드는 별도 블록.
  static List<Block> toBlocks(Delta delta) {
    final blocks = <Block>[];
    var buf = StringBuffer();
    var lineHasEmbed = false; // 이 줄이 이미지 임베드로 채워졌나 (개행이 빈 줄을 안 만들게)

    void flushLine(Map<String, dynamic>? attr) {
      final text = buf.toString();
      buf = StringBuffer();
      if (text.isEmpty && lineHasEmbed) {
        lineHasEmbed = false; // 임베드 줄을 끝내는 개행 — 빈 텍스트블록 만들지 않음
        return;
      }
      lineHasEmbed = false;
      final list = attr?['list'];
      if (list == 'checked' || list == 'unchecked') {
        blocks.add(todoBlock(text, list == 'checked'));
      } else {
        blocks.add(textBlock(text));
      }
    }

    for (final op in delta.toList()) {
      final data = op.data;
      if (data is String) {
        var s = data;
        while (true) {
          final nl = s.indexOf('\n');
          if (nl == -1) {
            buf.write(s);
            break;
          }
          buf.write(s.substring(0, nl));
          flushLine(op.attributes);
          s = s.substring(nl + 1);
        }
      } else if (data is Map) {
        // 임베드(이미지). 앞서 쌓인 텍스트가 있으면 먼저 블록으로 비운다.
        final img = data['image'];
        if (buf.isNotEmpty) {
          blocks.add(textBlock(buf.toString()));
          buf = StringBuffer();
        }
        if (img is String) {
          blocks.add(imageBlock(img));
          lineHasEmbed = true;
        }
      }
    }
    if (buf.isNotEmpty) blocks.add(textBlock(buf.toString()));

    // Quill 문서는 항상 \n로 끝나 마지막에 빈 TextBlock이 생긴다.
    // 블록이 2개 이상이고 마지막이 빈 텍스트면 하나만 떼어낸다.
    if (blocks.length > 1 &&
        blocks.last is TextBlock &&
        blocks.last.text.isEmpty) {
      blocks.removeLast();
    }
    if (blocks.isEmpty) blocks.add(textBlock());
    return blocks;
  }
}
