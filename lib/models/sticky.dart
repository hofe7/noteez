import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 스티커 한 줄(블록). 구조화 모델 = todo 상태가 1급 데이터.
/// 나중에 "내가 한 일" 보고/검색이 정규식 긁기 없이 공짜로 풀린다.
sealed class Block {
  final String id;
  final String text;
  const Block({required this.id, required this.text});

  Map<String, dynamic> toJson();

  factory Block.fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'todo':
        return TodoBlock(
          id: j['id'] as String,
          text: j['text'] as String,
          checked: j['checked'] as bool? ?? false,
          completedAt: j['completedAt'] as int?,
        );
      default:
        return TextBlock(id: j['id'] as String, text: j['text'] as String);
    }
  }
}

class TextBlock extends Block {
  const TextBlock({required super.id, required super.text});

  TextBlock copyWith({String? text}) => TextBlock(id: id, text: text ?? this.text);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'id': id, 'text': text};
}

class TodoBlock extends Block {
  final bool checked;
  final int? completedAt; // 체크된 시각(millis). 보고/회고용.
  const TodoBlock({
    required super.id,
    required super.text,
    this.checked = false,
    this.completedAt,
  });

  TodoBlock copyWith({
    String? text,
    bool? checked,
    int? completedAt,
    bool clearCompleted = false,
  }) =>
      TodoBlock(
        id: id,
        text: text ?? this.text,
        checked: checked ?? this.checked,
        completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'todo',
        'id': id,
        'text': text,
        'checked': checked,
        'completedAt': completedAt,
      };
}

Block textBlock([String text = '']) => TextBlock(id: _uuid.v4(), text: text);
Block todoBlock([String text = '', bool checked = false]) =>
    TodoBlock(id: _uuid.v4(), text: text, checked: checked);

class Sticky {
  final String id;
  final List<Block> blocks;
  final int colorIndex;
  final double x;
  final double y;
  final bool collapsed;
  final bool pinned; // 항상 위에 고정
  final bool open; // 책상 위(창 열림) vs 서랍(닫힘, 데이터 유지)
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sticky({
    required this.id,
    required this.blocks,
    required this.colorIndex,
    required this.x,
    required this.y,
    this.collapsed = false,
    this.pinned = false,
    this.open = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Sticky copyWith({
    List<Block>? blocks,
    int? colorIndex,
    double? x,
    double? y,
    bool? collapsed,
    bool? pinned,
    bool? open,
    DateTime? updatedAt,
  }) =>
      Sticky(
        id: id,
        blocks: blocks ?? this.blocks,
        colorIndex: colorIndex ?? this.colorIndex,
        x: x ?? this.x,
        y: y ?? this.y,
        collapsed: collapsed ?? this.collapsed,
        pinned: pinned ?? this.pinned,
        open: open ?? this.open,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'colorIndex': colorIndex,
        'x': x,
        'y': y,
        'collapsed': collapsed,
        'pinned': pinned,
        'open': open,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory Sticky.fromJson(Map<String, dynamic> j) => Sticky(
        id: j['id'] as String,
        colorIndex: j['colorIndex'] as int,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        collapsed: j['collapsed'] as bool? ?? false,
        pinned: j['pinned'] as bool? ?? false,
        open: j['open'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int),
        blocks: (j['blocks'] as List)
            .map((e) => Block.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 접혔을 때 헤더에 보여줄 한 줄.
  String get preview {
    for (final b in blocks) {
      if (b.text.trim().isNotEmpty) return b.text.trim();
    }
    return '빈 메모';
  }
}

/// 새 스티커 1개(빈 텍스트 블록 하나).
Sticky makeSticky({
  required double x,
  required double y,
  int colorIndex = 0,
  List<Block>? blocks,
}) {
  final now = DateTime.now();
  return Sticky(
    id: _uuid.v4(),
    blocks: blocks ?? [textBlock()],
    colorIndex: colorIndex,
    x: x,
    y: y,
    createdAt: now,
    updatedAt: now,
  );
}

/// 첫 실행 시 보여줄 시드(인메모리). Drift 붙기 전까지만.
List<Sticky> seedStickies() => [
      makeSticky(
        x: 140,
        y: 140,
        colorIndex: 0,
        blocks: [
          textBlock('고객사 A 미팅'),
          todoBlock('Redis 캐시 구조 옵션 정리'),
          todoBlock('견적서 보내기', true),
        ],
      ),
      makeSticky(
        x: 460,
        y: 220,
        colorIndex: 2,
        blocks: [
          textBlock('Noteez'),
          textBlock('그냥 적어. 필요할 때 찾아준다.'),
          textBlock('[] 로 할 일, 클릭으로 완료'),
        ],
      ),
    ];
