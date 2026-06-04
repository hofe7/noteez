import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../main_controller.dart';
import '../models/sticky.dart';
import '../sticky_palette.dart';

class SearchPaletteApp extends StatelessWidget {
  const SearchPaletteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(useMaterial3: true),
      home: const SearchPalette(),
    );
  }
}

class SearchPalette extends StatefulWidget {
  const SearchPalette({super.key});

  @override
  State<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends State<SearchPalette> with WindowListener {
  final TextEditingController _q = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onFieldKey);
  String _query = '';
  List<Sticky> _results = const [];
  Timer? _debounce;
  bool _capture = false; // 캡처 모드 vs 검색 모드

  // 캡처 모드: Enter=저장, Shift+Enter=줄바꿈.
  KeyEventResult _onFieldKey(FocusNode node, KeyEvent e) {
    if (_capture &&
        e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _commit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    mainController.searchTick.addListener(_onOpen);
    mainController.captureTick.addListener(_onCapture);
  }

  // ⌘⇧K: 검색 모드로 열기.
  void _onOpen() {
    _q.clear();
    _query = '';
    setState(() => _capture = false);
    _runSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  // ⌘⇧Space: 빠른 캡처 모드로 열기.
  void _onCapture() {
    _q.clear();
    _query = '';
    setState(() => _capture = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _commit() async {
    final t = _q.text;
    await _hide(); // 피드백 없이 바로 닫고 저장
    if (t.trim().isNotEmpty) await mainController.addStickyWithText(t);
  }

  void _onChanged(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), _runSearch);
  }

  // 의미검색은 메인 엔진의 ConnectionEngine 직접 사용(같은 isolate, IPC 불필요).
  Future<void> _runSearch() async {
    final r = await mainController.search(_query);
    if (!mounted) return;
    setState(() => _results = r);
  }

  @override
  void onWindowBlur() {
    _hide(); // 다른 곳 클릭하면 닫힘 (Spotlight 동작)
  }

  Future<void> _hide() async {
    await windowManager.hide();
  }

  Future<void> _open(Sticky s) async {
    await _hide();
    await mainController.showOne(s.id);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    mainController.searchTick.removeListener(_onOpen);
    mainController.captureTick.removeListener(_onCapture);
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Material(
      color: Colors.transparent,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            _hide();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                            _capture ? Icons.edit_outlined : Icons.search,
                            color: Colors.black45,
                            size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _q,
                          focusNode: _focus,
                          autofocus: true,
                          maxLines: _capture ? 3 : 1,
                          minLines: 1,
                          keyboardType: _capture
                              ? TextInputType.multiline
                              : TextInputType.text,
                          style: const TextStyle(fontSize: 18, height: 1.3),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _capture ? '메모 적기…' : '메모 검색…',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            if (!_capture) _onChanged(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_capture)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 16, 12),
                    child: Text(
                      '↵ 저장    ⇧↵ 줄바꿈    esc 취소',
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                  )
                else ...[
                  const Divider(height: 1),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Text('결과 없음',
                                style: TextStyle(color: Colors.black38)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: results.length,
                            itemBuilder: (_, i) => _resultTile(results[i]),
                          ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultTile(Sticky s) {
    final openTodos =
        s.blocks.whereType<TodoBlock>().where((t) => !t.checked).length;
    return InkWell(
      onTap: () => _open(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: StickyPalette.of(s.colorIndex),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (openTodos > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('할 일 $openTodos',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black38)),
              ),
          ],
        ),
      ),
    );
  }
}
