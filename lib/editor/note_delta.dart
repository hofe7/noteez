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
  // Quill이 모르는 속성은 ignore scope로 원문 Delta에 보존된다. 이를 줄의 안정적인
  // 식별자/완료시각 저장소로 사용한다. 텍스트를 편집해도 줄 끝 개행의 속성은 남는다.
  static const String idAttributeKey = 'noteez-id';
  static const String completedAtAttributeKey = 'noteez-completed-at';

  /// 블록들 → Delta. 각 줄은 개행으로 끝나고, 체크리스트는 개행에 line attr을 건다.
  static Delta fromBlocks(List<Block> blocks) {
    final d = Delta();
    for (final b in blocks) {
      switch (b) {
        case ImageBlock img:
          d.insert({'image': img.path});
          d.insert('\n', {idAttributeKey: img.id});
        case TodoBlock t:
          _insertLines(d, t.text, {
            'list': t.checked ? 'checked' : 'unchecked',
            if (t.completedAt != null) completedAtAttributeKey: t.completedAt,
          }, t.id);
        case TextBlock _:
          _insertLines(d, b.text, null, b.id);
      }
    }
    if (blocks.isEmpty) d.insert('\n');
    return d;
  }

  // 블록 본문이 여러 줄(블록 내 개행)일 수 있으니 줄마다 개행+attr을 넣는다.
  static void _insertLines(
    Delta d,
    String text,
    Map<String, dynamic>? lineAttr,
    String id,
  ) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isNotEmpty) d.insert(line);
      // 구버전 데이터에 블록 내부 개행이 있으면 편집 모델에서는 여러 줄/블록이
      // 된다. 첫 줄은 기존 id, 이후 줄은 결정적인 파생 id로 중복을 피한다.
      d.insert('\n', {...?lineAttr, idAttributeKey: i == 0 ? id : '$id:$i'});
    }
  }

  /// Delta → 블록들. 개행의 line attr로 줄 종류를 판정하고, 이미지 임베드는 별도 블록.
  static List<Block> toBlocks(Delta delta) {
    final blocks = <Block>[];
    final usedIds = <String>{};
    var buf = StringBuffer();
    String? pendingImagePath;

    String idFrom(Map<String, dynamic>? attr) {
      final raw = attr?[idAttributeKey];
      if (raw is String && raw.isNotEmpty && usedIds.add(raw)) return raw;
      // 새 줄이거나 Quill 편집 과정에서 id가 복제된 줄. 새 UUID를 한 번 부여하고
      // 다음 onChanged에서 Delta에 다시 심긴다.
      var id = textBlock().id;
      while (!usedIds.add(id)) {
        id = textBlock().id;
      }
      return id;
    }

    void flushLine(Map<String, dynamic>? attr) {
      final text = buf.toString();
      buf = StringBuffer();
      final imagePath = pendingImagePath;
      if (imagePath != null) {
        blocks.add(ImageBlock(id: idFrom(attr), path: imagePath));
        pendingImagePath = null;
        return;
      }
      final id = idFrom(attr);
      final list = attr?['list'];
      if (list == 'checked' || list == 'unchecked') {
        blocks.add(
          TodoBlock(
            id: id,
            text: text,
            checked: list == 'checked',
            completedAt: attr?[completedAtAttributeKey] as int?,
          ),
        );
      } else {
        blocks.add(TextBlock(id: id, text: text));
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
          blocks.add(TextBlock(id: idFrom(null), text: buf.toString()));
          buf = StringBuffer();
        }
        if (img is String) {
          pendingImagePath = img;
        }
      }
    }
    if (pendingImagePath != null) {
      blocks.add(ImageBlock(id: idFrom(null), path: pendingImagePath!));
    } else if (buf.isNotEmpty) {
      blocks.add(TextBlock(id: idFrom(null), text: buf.toString()));
    }

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

  /// 편집 전후 블록의 안정적인 id로 todo 완료시각을 병합한다.
  /// 텍스트가 바뀌거나 같은 문구가 여러 개여도 서로의 시각을 침범하지 않는다.
  static List<Block> mergeMetadata(
    List<Block> next,
    List<Block> previous, {
    int? nowMillis,
  }) {
    final oldById = {for (final b in previous) b.id: b};
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    return [
      for (final b in next)
        if (b is TodoBlock)
          if (b.checked)
            TodoBlock(
              id: b.id,
              text: b.text,
              checked: true,
              completedAt: switch (oldById[b.id]) {
                TodoBlock old when old.checked => old.completedAt,
                _ => now,
              },
            )
          else
            TodoBlock(id: b.id, text: b.text)
        else
          b,
    ];
  }

  /// Enter로 줄을 나누면 Quill의 기존 개행(=id)이 뒤쪽 줄로 이동할 수 있다.
  /// 기존 본문을 더 많이 가진 새 줄이 따로 생긴 경우 id를 그 줄로 되돌린다.
  /// 새 줄의 임시 id는 기존 id를 잘못 물고 있던 줄에 넘겨 모든 id를 유일하게 유지한다.
  static List<Block> reconcileIdentities(
    List<Block> next,
    List<Block> previous,
  ) {
    final out = [...next];
    final previousIds = {for (final b in previous) b.id};
    for (final old in previous) {
      final holder = out.indexWhere((b) => b.id == old.id);
      if (holder == -1) continue;
      var best = -1;
      var bestScore = _identityScore(old, out[holder]);
      for (var i = 0; i < out.length; i++) {
        if (i == holder || previousIds.contains(out[i].id)) continue;
        final score = _identityScore(old, out[i]);
        if (score > bestScore) {
          best = i;
          bestScore = score;
        }
      }
      if (best == -1 || bestScore == 0) continue;
      final temporaryId = out[best].id;
      out[best] = _withId(out[best], old.id);
      out[holder] = _withId(out[holder], temporaryId);
    }
    return out;
  }

  static int _identityScore(Block old, Block next) {
    if (old.runtimeType != next.runtimeType) return 0;
    final a = old.text;
    final b = next.text;
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 100000 + a.length;
    var prefix = 0;
    while (prefix < a.length &&
        prefix < b.length &&
        a.codeUnitAt(prefix) == b.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < a.length - prefix &&
        suffix < b.length - prefix &&
        a.codeUnitAt(a.length - 1 - suffix) ==
            b.codeUnitAt(b.length - 1 - suffix)) {
      suffix++;
    }
    return prefix + suffix;
  }

  static Block _withId(Block block, String id) => switch (block) {
    TextBlock b => TextBlock(id: id, text: b.text),
    TodoBlock b => TodoBlock(
      id: id,
      text: b.text,
      checked: b.checked,
      completedAt: b.completedAt,
    ),
    ImageBlock b => ImageBlock(id: id, path: b.path),
  };
}
