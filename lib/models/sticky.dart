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
      case 'image':
        return ImageBlock(id: j['id'] as String, path: j['path'] as String);
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

/// 붙여넣은 이미지 블록. 바이트는 컨테이너 파일로 저장하고 경로만 보관.
/// text는 빈 문자열 — 검색/임베딩/보고에는 잡히지 않음(이미지는 의미 텍스트 없음).
class ImageBlock extends Block {
  final String path; // 저장된 이미지 파일 절대경로
  const ImageBlock({required super.id, required this.path}) : super(text: '');

  @override
  Map<String, dynamic> toJson() => {'type': 'image', 'id': id, 'path': path};
}

Block textBlock([String text = '']) => TextBlock(id: _uuid.v4(), text: text);
Block todoBlock([String text = '', bool checked = false]) =>
    TodoBlock(id: _uuid.v4(), text: text, checked: checked);
Block imageBlock(String path) => ImageBlock(id: _uuid.v4(), path: path);

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

/// 첫 실행 시 책상에 놓이는 환영 메모 1장. 지우면 깨끗한 빈 화면.
/// 데모 데이터가 아니라 핵심 동작을 알려주는 진짜 안내 — 익히면 체크하고 버리면 됨.
List<Sticky> seedStickies() => [
      makeSticky(
        x: 320,
        y: 180,
        colorIndex: 2,
        blocks: [
          textBlock('Noteez 👋'),
          textBlock('그냥 적어. 필요할 때 찾아줄게.'),
          todoBlock('[] 치면 할 일 — 클릭으로 완료'),
          todoBlock('⌘⇧Space 어디서든 빠르게 캡처'),
          todoBlock('⌘⇧K 검색 · ⌘⇧G 전체 보기'),
        ],
      ),
    ];
