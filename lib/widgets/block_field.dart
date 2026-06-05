import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sticky.dart';

/// 블록 한 줄 에디터. 무거운 리치텍스트 프레임워크 없이,
/// todo는 Checkbox+텍스트(완료 시 취소선), text는 그냥 텍스트.
class BlockField extends StatefulWidget {
  final Block block;
  final bool shouldFocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnter;
  final VoidCallback onBackspaceEmpty;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onArrowUp; // 인자 = 현재 가로 위치(컬럼)
  final ValueChanged<int> onArrowDown;
  final bool isFirst; // 첫 블록(맨 위) — ↑ 시 맨 앞으로 커서
  final bool isLast; // 마지막 블록(맨 아래) — ↓ 시 맨 끝으로 커서
  final VoidCallback onToggleType; // ⌘L: 텍스트↔체크박스 토글
  // 네이티브 ⌘V 텍스트 붙여넣기: 신호가 틱하면 포커스된 필드만 pasteText()를 커서에 삽입.
  final ValueListenable<int>? pasteSignal;
  final String Function()? pasteText;
  final int? focusColumn; // 포커스 시 둘 위치(null=끝)
  final int focusTick; // 값 바뀌면(같은 shouldFocus라도) 다시 포커스

  const BlockField({
    super.key,
    required this.block,
    required this.shouldFocus,
    required this.onChanged,
    required this.onEnter,
    required this.onBackspaceEmpty,
    required this.onToggle,
    required this.onArrowUp,
    required this.onArrowDown,
    this.isFirst = false,
    this.isLast = false,
    required this.onToggleType,
    this.pasteSignal,
    this.pasteText,
    this.focusColumn,
    this.focusTick = 0,
  });

  @override
  State<BlockField> createState() => _BlockFieldState();
}

class _BlockFieldState extends State<BlockField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.block.text);
  late final FocusNode _f = FocusNode(onKeyEvent: _onKey);

  // 빈 블록에서 Backspace → 위로 병합. 비어있을 때만 처리하므로
  // 텍스트가 있을 땐 기본 삭제와 충돌하지 않는다.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _c.text.isEmpty) {
      widget.onBackspaceEmpty();
      return KeyEventResult.handled;
    }
    // Enter = 새 블록, Shift+Enter = 블록 안 줄바꿈(그대로 통과).
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      widget.onEnter();
      return KeyEventResult.handled;
    }
    // 첫 줄에서 ↑ = 이전 블록, 마지막 줄에서 ↓ = 다음 블록.
    // Shift 누르면 통과 → 텍스트 선택(드래그) 동작 보존.
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.arrowUp &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final sel = _c.selection.baseOffset;
      final before = (sel <= 0) ? '' : _c.text.substring(0, sel);
      if (!before.contains('\n')) {
        // 첫 블록의 첫 줄에서 ↑ = 맨 앞으로 커서. 그 외엔 이전 블록으로.
        if (widget.isFirst) {
          _c.selection = const TextSelection.collapsed(offset: 0);
        } else {
          widget.onArrowUp(_column());
        }
        return KeyEventResult.handled;
      }
    }
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.arrowDown &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final sel = _c.selection.baseOffset;
      final after = (sel < 0 || sel > _c.text.length) ? '' : _c.text.substring(sel);
      if (!after.contains('\n')) {
        // 마지막 블록의 마지막 줄에서 ↓ = 맨 끝으로 커서. 그 외엔 다음 블록으로.
        if (widget.isLast) {
          _c.selection =
              TextSelection.collapsed(offset: _c.text.length);
        } else {
          widget.onArrowDown(_column());
        }
        return KeyEventResult.handled;
      }
    }
    // Tab = 들여쓰기. 탭 문자는 탭 스톱이 없어 한 칸처럼 보이므로 스페이스 4칸 삽입.
    // 기본 동작(다음 위젯으로 포커스 이동)을 막는다.
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed) {
      const indent = '    '; // 스페이스 4칸
      final sel = _c.selection;
      final base = (sel.isValid && sel.start >= 0)
          ? sel
          : TextSelection.collapsed(offset: _c.text.length);
      final nt = _c.text.replaceRange(base.start, base.end, indent);
      _c.value = TextEditingValue(
        text: nt,
        selection: TextSelection.collapsed(offset: base.start + indent.length),
      );
      widget.onChanged(nt);
      return KeyEventResult.handled;
    }
    // ⌘L: 현재 줄 텍스트↔체크박스 토글
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.keyL &&
        HardwareKeyboard.instance.isMetaPressed) {
      widget.onToggleType();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // 현재 캐럿의 가로 위치(현재 줄 시작부터의 거리).
  int _column() {
    final off = _c.selection.baseOffset;
    if (off < 0) return _c.text.length;
    final before = _c.text.substring(0, off);
    final nl = before.lastIndexOf('\n');
    return off - (nl + 1);
  }

  void _focusSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _f.requestFocus();
      final len = _c.text.length;
      final col = widget.focusColumn;
      final off = (col == null) ? len : (col > len ? len : col);
      _c.selection = TextSelection.collapsed(offset: off);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.shouldFocus) _focusSoon();
    widget.pasteSignal?.addListener(_onPasteSignal);
  }

  // 네이티브 ⌘V 텍스트 붙여넣기 신호. 포커스된 필드만 커서 위치에 삽입.
  void _onPasteSignal() {
    if (!_f.hasFocus) return;
    final t = widget.pasteText?.call();
    if (t == null || t.isEmpty) return;
    final sel = _c.selection;
    final base = (sel.isValid && sel.start >= 0)
        ? sel
        : TextSelection.collapsed(offset: _c.text.length);
    final nt = _c.text.replaceRange(base.start, base.end, t);
    _c.value = TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: base.start + t.length),
    );
    widget.onChanged(nt);
  }

  @override
  void didUpdateWidget(covariant BlockField old) {
    super.didUpdateWidget(old);
    if (widget.block.text != _c.text) {
      final sel = _c.selection;
      final len = widget.block.text.length;
      _c.value = TextEditingValue(
        text: widget.block.text,
        selection: sel.isValid && sel.start <= len
            ? sel
            : TextSelection.collapsed(offset: len),
      );
    }
    if (widget.shouldFocus &&
        (!old.shouldFocus || widget.focusTick != old.focusTick)) {
      _focusSoon();
    }
  }

  @override
  void dispose() {
    widget.pasteSignal?.removeListener(_onPasteSignal);
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final isTodo = block is TodoBlock;
    final checked = block is TodoBlock && block.checked;

    final field = TextField(
      controller: _c,
      focusNode: _f,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontSize: 14,
        height: 1.3,
        // 글자를 줄 박스 가운데로(기본은 위로 붙어서 체크박스와 어긋남).
        leadingDistribution: TextLeadingDistribution.even,
        decoration:
            checked ? TextDecoration.lineThrough : TextDecoration.none,
        color: checked ? Colors.black38 : Colors.black87,
      ),
      cursorColor: Colors.black54,
      cursorWidth: 1.4,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 3),
        hintText: isTodo ? '할 일' : null,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
      ),
    );

    // 구조를 항상 Row[리딩칸, 필드]로 고정 → text↔todo 변환 시 TextField가
    // remount 되지 않아 포커스/커서가 그대로 유지됨(변환 직후 바로 입력 가능).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 리딩칸: todo면 체크박스, text면 0폭(자리 유지).
        if (isTodo)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onToggle(!checked),
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 1, right: 8),
              decoration: BoxDecoration(
                color: checked ? Colors.black54 : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? Colors.black54 : Colors.black38,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          )
        else
          const SizedBox.shrink(),
        Expanded(child: field),
      ],
    );
  }
}
