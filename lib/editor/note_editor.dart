import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;

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
    final doc = Document.fromJson(NoteDelta.fromBlocks(widget.initial).toJson());
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

  void _onChange() {
    final blocks = NoteDelta.toBlocks(_controller.document.toDelta());
    final merged = _mergeCompleted(blocks, _prev);
    _prev = merged;
    widget.onChanged(merged);
  }

  // 체크된 todo의 완료시각 보존: 직전에 같은 텍스트로 체크돼 있던 todo면 그 시각 유지,
  // 아니면(새로 체크) now.
  List<Block> _mergeCompleted(List<Block> nw, List<Block> old) {
    final wasChecked = <String, int?>{};
    for (final b in old) {
      if (b is TodoBlock && b.checked) wasChecked[b.text] = b.completedAt;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final b in nw)
        if (b is TodoBlock && b.checked)
          b.copyWith(completedAt: wasChecked[b.text] ?? now)
        else
          b
    ];
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

// 스티커 본문 스타일: 가벼운 14px + 좁은 줄 간격 + 미니 체크박스(포스트잇 색조).
// base.merge(부분) 으로 null 필드는 기본 유지 → 완전한 DefaultStyles.
DefaultStyles _stickyStyles(BuildContext context, Color accent) {
  final base = DefaultStyles.getInstance(context);
  const text = TextStyle(
    fontSize: 14,
    height: 1.3,
    color: Color(0xDE000000), // black87
    leadingDistribution: TextLeadingDistribution.even,
  );
  // 블록 상/하 여백을 0으로 — 줄 간격은 전적으로 line-height(1.3)가 책임진다.
  // 체크 토글로 체크리스트가 두 블록으로 쪼개져도 블록 경계 여백이 0이라 행 간격
  // 불변(이전엔 블록당 2+2px가 끼어 토글 시 4px씩 튀었음).
  const tightV = VerticalSpacing(0, 0);
  const tightLine = VerticalSpacing(0, 0);
  return base.merge(DefaultStyles(
    paragraph: DefaultTextBlockStyle(
        text, base.paragraph!.horizontalSpacing, tightV, tightLine, null),
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
    placeHolder: DefaultTextBlockStyle(
        const TextStyle(
            fontSize: 14,
            height: 1.3,
            color: Color(0x42000000),
            leadingDistribution: TextLeadingDistribution.even),
        base.placeHolder!.horizontalSpacing,
        base.placeHolder!.verticalSpacing,
        base.placeHolder!.lineSpacing,
        null),
  ));
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
            child: Icon(Icons.check,
                size: 11,
                color: isChecked ? Colors.white : Colors.transparent),
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
            child: const Text('이미지를 불러올 수 없어요',
                style: TextStyle(fontSize: 11, color: Colors.black38)),
          ),
        ),
      ),
    );
  }
}
