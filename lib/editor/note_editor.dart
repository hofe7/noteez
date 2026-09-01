// SpaceShortcutEvent 등 flutter_quill 단축 API는 @experimental 로 표시돼 있으나
// 안정 동작이라 의도적으로 사용한다.
// ignore_for_file: experimental_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_quill/quill_delta.dart';

import '../models/sticky.dart';
import 'note_delta.dart';

/// 스티커 본문 에디터. 단일 QuillEditor라 줄 넘는 선택·⌘A·⌘C/⌘V가 기본 동작.
/// 바깥엔 여전히 블록 모델로 노출(검색/보고/저장 그대로) — Delta는 편집 표현일 뿐.
///
/// scrollable:false 라 내용 크기에 맞춰 자라고(스티커 자동 높이), todo 완료시각은
/// 직전 블록과 매칭해 보존한다(체크 유지=시각 유지, 새로 체크=now).
class NoteEditor extends StatefulWidget {
  final List<Block> initial;
  final ValueChanged<List<Block>> onChanged;
  final bool autofocus;
  final Color accent; // 체크박스 등 강조색 (포스트잇 색조의 진한 잉크)
  const NoteEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.autofocus = false,
    this.accent = const Color(0xFF8A6418),
  });

  @override
  State<NoteEditor> createState() => NoteEditorState();
}

class NoteEditorState extends State<NoteEditor> {
  late final QuillController _controller;
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  late List<Block> _prev;
  bool _stampingMetadata = false;

  QuillController get controller => _controller;

  /// 에디터에 포커스 + 커서를 문서 끝으로. (빈 영역 탭 / 검색 소환 시)
  void focusEnd() {
    _focus.requestFocus();
    final len = _controller.document.length;
    _controller.updateSelection(
      TextSelection.collapsed(offset: len > 0 ? len - 1 : 0),
      ChangeSource.local,
    );
  }

  @override
  void initState() {
    super.initState();
    _prev = widget.initial;
    final doc = Document.fromJson(
      NoteDelta.fromBlocks(widget.initial).toJson(),
    );
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_onChange);
    // autoFocus를 config로 주면 레이아웃 전에 IME가 열리며 RenderEditor.size를 읽어
    // 터진다(scrollable:false). 레이아웃 끝난 다음 프레임에 포커스를 준다.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  /// 줄 맨 앞에서 백스페이스 → 그 줄의 블록 포맷(체크리스트/리스트 등) 제거 후
  /// 일반 빈 줄로. flutter_quill 기본은 문서 맨 처음(offset 0)에서만 블록을 풀고,
  /// 그 외엔 이전 줄과 병합(=행 삭제)해버린다. 체크박스를 지우면 행이 통째로
  /// 사라지던 문제를 막는다. (반환 null이면 기본 동작 유지.)
  KeyEventResult? _onKey(KeyEvent event, Node? node) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return null;
    final sel = _controller.selection;
    if (!sel.isCollapsed) return null;
    final off = sel.baseOffset;
    // 줄 맨 앞인가 — 문서 처음이거나 직전 글자가 개행. (줄 경계 offset에서
    // queryChild가 이전 줄을 돌려줄 수 있어 node 대신 이 방식으로 판별한다.)
    final atLineStart =
        off == 0 || _controller.document.getPlainText(off - 1, 1) == '\n';
    if (!atLineStart) return null;
    // 현재 줄의 블록 포맷(체크리스트/리스트 등).
    final blockAttrs = _controller
        .getSelectionStyle()
        .attributes
        .values
        .where((a) => a.scope == AttributeScope.block)
        .toList();
    if (blockAttrs.isEmpty) return null; // 일반 줄 → 기본 백스페이스(이전 줄과 병합)
    for (final a in blockAttrs) {
      _controller.formatSelection(Attribute.clone(a, null));
    }
    return KeyEventResult.handled;
  }

  void _onChange() {
    if (_stampingMetadata) return;
    final blocks = NoteDelta.toBlocks(_controller.document.toDelta());
    final identified = NoteDelta.reconcileIdentities(blocks, _prev);
    final merged = NoteDelta.mergeMetadata(identified, _prev);
    _stampMetadata(merged);
    _prev = merged;
    widget.onChanged(merged);
  }

  /// 새 줄에는 아직 Noteez id가 없다. 현재 Delta의 각 줄 끝 개행에 안정적인 id와
  /// todo 완료시각을 심는다. 화면용 속성이 아니며 listener 알림도 생략해 재귀
  /// onChanged를 막는다.
  void _stampMetadata(List<Block> blocks) {
    final delta = _controller.document.toDelta();
    final changes = <({int offset, Map<String, dynamic> attributes})>[];
    var offset = 0;
    var blockIndex = 0;
    for (final op in delta.toList()) {
      final data = op.data;
      if (data is! String) {
        offset += 1; // embed length
        continue;
      }
      var from = 0;
      while (true) {
        final nl = data.indexOf('\n', from);
        if (nl == -1) break;
        if (blockIndex >= blocks.length) return;
        final block = blocks[blockIndex++];
        final attrs = op.attributes;
        final patch = <String, dynamic>{};
        if (attrs?[NoteDelta.idAttributeKey] != block.id) {
          patch[NoteDelta.idAttributeKey] = block.id;
        }
        final completed = block is TodoBlock && block.checked
            ? block.completedAt
            : null;
        if (attrs?[NoteDelta.completedAtAttributeKey] != completed) {
          patch[NoteDelta.completedAtAttributeKey] = completed;
        }
        if (patch.isNotEmpty) {
          changes.add((offset: offset + nl, attributes: patch));
        }
        from = nl + 1;
      }
      offset += data.length;
    }
    if (changes.isEmpty) return;

    // Quill format rule은 사용자 정의 ignore attribute를 받지 않으므로 raw Delta
    // retain으로 메타데이터만 합성한다. remote source라 undo 스택에 사용자 편집으로
    // 쌓이지 않으며, guard가 합성 알림의 재귀 처리를 막는다.
    final metadata = Delta();
    var cursor = 0;
    for (final change in changes) {
      final gap = change.offset - cursor;
      if (gap > 0) metadata.retain(gap);
      metadata.retain(1, change.attributes);
      cursor = change.offset + 1;
    }
    _stampingMetadata = true;
    try {
      _controller.compose(metadata, _controller.selection, ChangeSource.remote);
    } finally {
      _stampingMetadata = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor(
      controller: _controller,
      focusNode: _focus,
      scrollController: _scroll,
      config: QuillEditorConfig(
        scrollable: false, // 내용 크기에 맞춰 자람 → 스티커 자동 높이와 호환
        expands: false,
        autoFocus: false, // 포커스는 initState의 post-frame에서(레이아웃 후) 처리
        // 바깥 여백은 여기(블록 분할과 무관한 상수)서만 준다 — 블록 상/하 여백은 0.
        padding: const EdgeInsets.symmetric(vertical: 2),
        placeholder: '메모…',
        // 줄 시작에서 "[]" 또는 "[ ]" + 스페이스 → 체크박스(미체크 todo).
        // flutter_quill 기본은 단축이 전부 꺼져 있고(표준 리스트에도 체크박스 없음)
        // 직접 정의한다. 매칭 안 되면 스페이스는 그대로 입력됨.
        spaceShortcutEvents: noteSpaceShortcuts,
        // 줄 맨 앞 백스페이스 → 블록 포맷 해제(체크박스 지우면 빈 줄 유지).
        onKeyPressed: _onKey,
        customStyles: _stickyStyles(context, widget.accent),
        // 체크된 체크리스트 줄(list:checked): 취소선 + 회색만. 줄 높이/여백은
        // 본문 메트릭(_stickyStyles)에서 전부 결정 → 체크/미체크가 픽셀까지 동일.
        customStyleBuilder: (attr) =>
            (attr.key == Attribute.list.key && attr.value == 'checked')
            ? const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.black45,
              )
            : const TextStyle(),
        embedBuilders: [LocalImageEmbedBuilder()],
      ),
    );
  }
}

/// 체크리스트 입력 단축: 줄 전체가 "[]"(또는 "[ ]")일 때 스페이스를 누르면 그 줄을
/// 미체크 todo로 바꾼다. flutter_quill의 BlockFormatStyle.todo 핸들러는 비공개라
/// 공개 컨트롤러 API로 재구현. (디스패처는 줄 텍스트가 character와 정확히 일치할
/// 때만 호출하므로 줄 시작 전용 + 오발동 없음.)
SpaceShortcutEvent _todoShortcut(String phrase) => SpaceShortcutEvent(
  character: phrase,
  handler: (node, controller) {
    final base = controller.selection.baseOffset;
    // 트리거 문구를 지우고(줄이 비워짐) 현재 줄을 체크리스트(미체크)로 포맷.
    controller.replaceText(base - phrase.length, phrase.length, '', null);
    controller.updateSelection(
      TextSelection.collapsed(offset: base - phrase.length),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.unchecked);
    return true;
  },
);

/// NoteEditor에 주입하는 스페이스 단축 목록 (현재는 체크박스 2종).
final List<SpaceShortcutEvent> noteSpaceShortcuts = [
  _todoShortcut('[]'),
  _todoShortcut('[ ]'),
];

// 스티커 본문 스타일: 가벼운 14px + 좁은 줄 간격 + 미니 체크박스(포스트잇 색조).
// base.merge(부분) 으로 null 필드는 기본 유지 → 완전한 DefaultStyles.
DefaultStyles _stickyStyles(BuildContext context, Color accent) {
  final base = DefaultStyles.getInstance(context);
  // 모든 줄에 leadingDistribution 미지정(기본 분배). even을 쓰면 height>1.0에서
  // 빈 줄(글리프 없음)의 strut 높이가 값 있는 줄과 어긋나(빈 줄이 더 큼) "그냥 개행"
  // 과 "값 입력한 줄"의 높이가 달라진다. 기본 분배면 빈 줄==값 줄로 일치(본문·체크
  // 리스트 모두). 체크박스 세로 정렬은 _MiniCheckbox 에서 직접 맞춘다.
  const text = TextStyle(
    fontSize: 14,
    height: 1.3,
    color: Color(0xDE000000), // black87
  );
  // 블록 상/하 여백을 0으로 — 줄 간격은 전적으로 line-height(1.3)가 책임진다.
  // 체크 토글로 체크리스트가 두 블록으로 쪼개져도 블록 경계 여백이 0이라 행 간격
  // 불변(이전엔 블록당 2+2px가 끼어 토글 시 4px씩 튀었음).
  const tightV = VerticalSpacing(0, 0);
  const tightLine = VerticalSpacing(0, 0);
  return base.merge(
    DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        text,
        base.paragraph!.horizontalSpacing,
        tightV,
        tightLine,
        null,
      ),
      lists: DefaultListBlockStyle(
        text,
        base.lists!.horizontalSpacing,
        tightV,
        tightLine,
        null,
        _MiniCheckbox(accent),
        // 체크리스트 거터를 좁힘(기본 fontSize*2=28 → 22) — 체크박스 좌측 여백 축소.
        indentWidthBuilder: (block, context, count, npb) =>
            const HorizontalSpacing(22, 0),
      ),
      // 플레이스홀더는 본문과 같은 메트릭(even 없음, 여백 0) — 첫 글자 입력 시 줄이
      // 튀지 않게 한다.
      placeHolder: DefaultTextBlockStyle(
        const TextStyle(fontSize: 14, height: 1.3, color: Color(0x42000000)),
        base.placeHolder!.horizontalSpacing,
        tightV,
        tightLine,
        null,
      ),
    ),
  );
}

/// 미니멀 체크박스 — 기존 스티커 디자인(16×16 둥근 사각 + 체크) + 포스트잇 색조 잉크.
class _MiniCheckbox extends QuillCheckboxBuilder {
  final Color accent;
  _MiniCheckbox(this.accent);

  // 기본 QuillCheckboxPoint 의 레이아웃(centerEnd 정렬 + 끝 패딩 + 고정 SizedBox)을
  // 그대로 따라 정사각형 유지 + 체크/미체크 동일 크기로 줄 흔들림 방지.
  static const double _size = 14;

  @override
  Widget build({
    required BuildContext context,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      // 글자가 줄 박스 가운데(even)라 체크박스도 세로 중앙 정렬로 맞춤.
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!isChecked),
        child: SizedBox(
          width: _size,
          height: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isChecked ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isChecked ? accent : accent.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            // 체크/미체크 모두 Icon을 둔다(미체크는 투명) → leading 메트릭이 같아
            // 토글 시 줄이 위아래로 튀지 않음.
            child: Icon(
              Icons.check,
              size: 11,
              color: isChecked ? Colors.white : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

/// 로컬 파일 이미지 임베드({'image': '/path.png'}) 렌더.
class LocalImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    if (data is! String) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(data),
          fit: BoxFit.fitWidth,
          width: double.infinity,
          errorBuilder: (context, error, stack) => Container(
            height: 44,
            alignment: Alignment.center,
            color: const Color(0x11000000),
            child: const Text(
              '이미지를 불러올 수 없어요',
              style: TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ),
        ),
      ),
    );
  }
}
