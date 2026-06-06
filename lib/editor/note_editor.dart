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
  const NoteEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.autofocus = false,
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
        padding: EdgeInsets.zero,
        placeholder: '메모…',
        // 체크된 체크리스트 줄(list:checked)에 취소선+회색 — 기존 todo 완료 표시 유지.
        customStyleBuilder: (attr) =>
            (attr.key == Attribute.list.key && attr.value == 'checked')
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.black45)
                : const TextStyle(),
        embedBuilders: [LocalImageEmbedBuilder()],
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
