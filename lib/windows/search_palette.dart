import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../app_theme.dart';
import '../file_dialog_host.dart';
import '../date_util.dart';
import '../main_controller.dart';
import '../models/sticky.dart';
import '../models/saved_note_open_failure.dart';
import '../sticky_palette.dart';
import 'search_palette_widgets.dart';

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
  const SearchPalette({super.key, this.controller});
  final MainController? controller;

  @override
  State<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends State<SearchPalette> with WindowListener {
  MainController get _controller => widget.controller ?? mainController;
  int _searchGeneration = 0;
  bool _saving = false;
  String? _error;

  final TextEditingController _q = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onFieldKey);
  String _query = '';
  List<Sticky> _results = const []; // 평면: 정확 일치 + 관련 (키보드 nav/패널용)
  int _exactCount = 0; // _results 중 앞쪽 '정확 일치' 개수 (나머지는 'AI 관련')
  final DateTime _now = DateTime.now();
  Timer? _debounce;
  bool _capture = false; // 캡처 모드 vs 검색 모드
  int _selected = 0; // 검색 결과 키보드 선택 인덱스
  final ScrollController _scroll = ScrollController();
  bool _split = false; // 관련 표시 방식: false=컴팩트(하단), true=분할(우측 패널)
  String? _panelId; // 관련 패널이 보여줄 대상 메모 id (선택/hover 따라감)

  static const double _rowExtent = 46; // 결과 행 고정 높이(스크롤 계산용)
  static const Size _compactSize = Size(596, 484);
  static const Size _splitSize = Size(880, 484);

  bool get _browsing => !_capture && _query.trim().isEmpty;
  Sticky? get _selectedSticky =>
      (!_capture && _results.isNotEmpty && _selected < _results.length)
      ? _results[_selected]
      : null;

  // 색은 전부 AppColors(단일 소스) 별칭 — 로컬 이름만 유지.
  static const Color _accent = AppColors.accent; // 시그니처 허니 앰버
  static const Color _panel = AppColors.surface; // 검색: 따뜻한 오프화이트
  static const Color _paper = AppColors.paper; // 캡처: 포스트잇 종이색
  static const Color _inkOnPaper = AppColors.inkOnPaper; // 종이 위 캐럿/아이콘

  // 결과 목록에서 "새 메모" 행을 포함한 전체 선택 가능 항목 수.
  // 쿼리가 있으면 맨 끝에 "'쿼리'로 새 메모" 행이 하나 더 붙는다.
  bool get _hasCreateRow => _query.trim().isNotEmpty;
  int get _itemCount => _results.length + (_hasCreateRow ? 1 : 0);
  bool get _onCreateRow => _hasCreateRow && _selected == _results.length;

  // 캡처 모드: Enter=저장, Shift+Enter=줄바꿈.
  // 검색 모드: ↑↓=결과 이동, Enter=선택 항목 열기(또는 새 메모).
  KeyEventResult _onFieldKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (_capture) {
      if (e.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _commit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // 검색 모드 — 둘러보기(빈 검색)는 마우스로 탐색.
    if (_browsing) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _activateSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _move(int delta) {
    if (_itemCount == 0) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, _itemCount - 1);
      _panelId = _selected < _results.length ? _results[_selected].id : null;
    });
    _ensureVisible();
  }

  // 선택된 항목 실행: 결과면 그 메모 열기, "새 메모" 행이면 캡처처럼 생성.
  void _activateSelected() {
    if (_onCreateRow) {
      _createFromQuery();
    } else if (_results.isNotEmpty && _selected < _results.length) {
      _open(_results[_selected]);
    }
  }

  Future<void> _createFromQuery() async {
    await _saveCapture(_query);
  }

  Future<void> _saveCapture(String text) async {
    if (_saving || text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _controller.addStickyWithText(text);
      if (!mounted) return;
      _q.clear();
      _query = '';
      await _hide();
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is SavedNoteOpenFailure) {
            _q.clear();
            _query = '';
            _error = '메모는 저장했어요. 창을 열지 못해 검색에서 다시 열어 주세요.';
          } else {
            _error = '저장하지 못했어요. 입력은 그대로예요. 다시 시도해 주세요.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _ensureVisible() {
    if (!_scroll.hasClients) return;
    final target = _selected * _rowExtent;
    final vp = _scroll.position.viewportDimension;
    final cur = _scroll.offset;
    if (target < cur) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else if (target + _rowExtent > cur + vp) {
      _scroll.animateTo(
        target + _rowExtent - vp,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _controller.searchTick.addListener(_onOpen);
    _controller.captureTick.addListener(_onCapture);
    _controller.modelTick.addListener(_onModelState);
  }

  void _onModelState() {
    if (mounted) setState(() {});
  }

  // ⌘⇧K: 검색 모드로 열기.
  void _onOpen() {
    if (_saving) return;
    _searchGeneration++;
    if (_error != null && _q.text.isNotEmpty) return;
    _error = null;
    _q.clear();
    _query = '';
    _panelId = null;
    setState(() {
      _capture = false;
      _selected = 0;
    });
    _applyWindowSize();
    _runSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _applyWindowSize() async {
    final s = _split ? _splitSize : _compactSize;
    await windowManager.setSize(s);
    await windowManager.center();
  }

  void _toggleSplit() {
    setState(() => _split = !_split);
    _applyWindowSize();
  }

  // ⌘⇧Space: 빠른 캡처 모드로 열기.
  void _onCapture() {
    if (_saving) return;
    _searchGeneration++;
    _debounce?.cancel();
    if (_error != null && _q.text.isNotEmpty) return;
    _error = null;
    _q.clear();
    _query = '';
    setState(() => _capture = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _commit() async {
    await _saveCapture(_q.text);
  }

  void _onChanged(String v) {
    _query = v;
    _searchGeneration++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), _runSearch);
  }

  // 의미검색은 메인 엔진의 ConnectionEngine 직접 사용(같은 isolate, IPC 불필요).
  Future<void> _runSearch() async {
    if (_capture) return;
    final generation = ++_searchGeneration;
    final query = _query;
    final r = await _controller.search(query);
    if (!mounted || _capture || generation != _searchGeneration) return;
    setState(() {
      _results = [...r.exact, ...r.related];
      _exactCount = r.exact.length;
      _selected = 0; // 새 결과 → 맨 위 선택
      _panelId = _results.isNotEmpty ? _results.first.id : null;
    });
  }

  @override
  void onWindowBlur() {
    // A native file panel takes focus from its parent. Hiding the parent here
    // also hides the sheet and makes the tray action appear to do nothing.
    if (!fileDialogHost.active && !_saving && _error == null) _hide();
  }

  Future<void> _hide() async {
    await windowManager.hide();
  }

  Future<void> _open(Sticky s) async {
    await _hide();
    await _controller.showOne(s.id);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _controller.searchTick.removeListener(_onOpen);
    _controller.captureTick.removeListener(_onCapture);
    _controller.modelTick.removeListener(_onModelState);
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    _scroll.dispose();
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
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          decoration: BoxDecoration(
            color: _capture ? _paper : _panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _capture
                  ? const Color(0x14000000)
                  : const Color(0x0F000000),
            ),
            boxShadow: const [
              // 2겹: 넓고 옅은 앰비언트 + 가까운 또렷한 그림자 → 떠 있는 느낌.
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
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
                        _capture ? Icons.sticky_note_2_outlined : Icons.search,
                        color: _capture ? _inkOnPaper : Colors.black38,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _q,
                        readOnly: _saving,
                        focusNode: _focus,
                        autofocus: true,
                        maxLines: _capture ? 3 : 1,
                        minLines: 1,
                        keyboardType: _capture
                            ? TextInputType.multiline
                            : TextInputType.text,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: _capture ? _inkOnPaper : _accent,
                        cursorWidth: 2,
                        cursorRadius: const Radius.circular(1),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _capture ? '여기에 메모…' : '메모 검색…',
                          hintStyle: TextStyle(
                            color: _capture
                                ? _inkOnPaper.withValues(alpha: 0.45)
                                : Colors.black26,
                            fontWeight: FontWeight.w400,
                          ),
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (_capture) ...[
                const Spacer(), // 힌트를 종이 바닥에 고정(스티커 푸터처럼)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 8, 16, 14),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _inkOnPaper.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Text(
                    '↵ 저장    ⇧↵ 줄바꿈    esc 취소',
                    style: TextStyle(
                      fontSize: 11,
                      color: _inkOnPaper.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ] else ...[
                if (_browsing) dateChips(_applyChip),
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 18,
                  endIndent: 16,
                  color: Color(0x0D000000),
                ),
                Expanded(
                  child: _split
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 5, child: _mainList(results)),
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Color(0x0D000000),
                            ),
                            Expanded(flex: 4, child: _relatedPanel()),
                          ],
                        )
                      : _mainList(results),
                ),
                if (!_split && !_browsing && _relatedItems().isNotEmpty)
                  _relatedInline(),
                if (!_browsing &&
                    (!_controller.hasSelectedModel ||
                        _controller.modelIndexing))
                  _modelStatus(),
                _footerHint(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultTile(Sticky s, int i) {
    final openTodos = s.blocks
        .whereType<TodoBlock>()
        .where((t) => !t.checked)
        .length;
    return paletteRow(
      selected: _selected == i,
      onTap: () => _open(s),
      onHover: () => _selectByHover(i),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: StickyPalette.of(s.colorIndex),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x14000000)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                previewText(s.preview, i < _exactCount, _query),
                const SizedBox(height: 2),
                Text(
                  relativeDate(s.createdAt, _now),
                  style: const TextStyle(fontSize: 10.5, color: Colors.black38),
                ),
              ],
            ),
          ),
          if (openTodos > 0) todoBadge(openTodos),
        ],
      ),
    );
  }

  // "'쿼리'로 새 메모" 행 — 결과 목록 맨 끝. Enter/클릭으로 생성.
  Widget _createTile(int i) {
    return paletteRow(
      selected: _selected == i,
      onTap: _createFromQuery,
      onHover: () => _selectByHover(i),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add, size: 10, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                children: [
                  TextSpan(
                    text: '“${_query.trim()}”',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const TextSpan(text: ' 새 메모'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _selectByHover(int i) {
    setState(() {
      _selected = i;
      if (i < _results.length) _panelId = _results[i].id;
    });
  }

  void _applyChip(String t) {
    _q.text = t;
    _query = t;
    _q.selection = TextSelection.collapsed(offset: t.length);
    _runSearch();
    _focus.requestFocus();
  }

  // 빈 검색 = 최근 메모(런처답게). 묶음 둘러보기/정리는 전체 보기(⌘⇧G)가 담당.
  // 타이핑 시 = 정확 일치 + "AI 관련" 구역. (선택 메모의 '같은 묶음'은 패널로 유지.)
  Widget _mainList(List<Sticky> results) {
    if (results.isEmpty && !_hasCreateRow) return emptyState();
    final children = <Widget>[];
    for (var i = 0; i < _exactCount && i < results.length; i++) {
      children.add(_resultTile(results[i], i));
    }
    if (results.length > _exactCount) {
      children.add(sectionLabel('AI 관련'));
      for (var i = _exactCount; i < results.length; i++) {
        children.add(_resultTile(results[i], i));
      }
    }
    if (_hasCreateRow) children.add(_createTile(results.length));
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: children,
    );
  }

  // 메모 한 줄(색칩 + 미리보기). 클릭 → 그 메모 소환. (관련 패널에서 사용)
  Widget _noteRow(
    Map<String, dynamic> m, {
    bool bold = false,
    bool indent = false,
    Widget? trailing,
  }) {
    return MouseRegion(
      onEnter: (_) {
        final id = m['id'] as String;
        if (_panelId != id) setState(() => _panelId = id);
      },
      child: InkWell(
        onTap: () => _openId(m['id'] as String),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.fromLTRB(indent ? 26 : 12, 8, 12, 8),
          child: Row(
            children: [
              colorChip(m['color'] as int),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  m['preview'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: bold ? Colors.black87 : Colors.black54,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openId(String id) async {
    await _hide();
    await _controller.showOne(id);
  }

  // 관련 패널 대상 = hover/선택 중인 메모. 없으면 선택된 결과.
  String? get _panelTargetId => _panelId ?? _selectedSticky?.id;

  // 대상 메모와 '같은 묶음'인 메모들.
  List<Map<String, dynamic>> _relatedItems() {
    final id = _panelTargetId;
    return id == null ? const [] : _controller.sameGroup(id);
  }

  // 분할 모드: 우측 패널에 hover/선택 메모의 같은-묶음 메모.
  Widget _relatedPanel() {
    final id = _panelTargetId;
    final items = _relatedItems();
    return Container(
      color: const Color(0x04000000),
      child: id == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '메모에 마우스를 올리면\n같은 묶음 메모가 여기에',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black38,
                    height: 1.5,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              children: [
                _panelCurrent(id),
                const SizedBox(height: 10),
                relatedHeader(_relatedItems().length),
                const SizedBox(height: 2),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Text(
                      '이 메모는 아직 다른 메모와 묶이지 않았어요',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black38,
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  for (final m in items) _noteRow(m),
              ],
            ),
    );
  }

  // 컴팩트 모드: 하단에 선택 결과의 같은-묶음 메모(살짝).
  Widget _relatedInline() {
    final items = _relatedItems();
    return Container(
      constraints: const BoxConstraints(maxHeight: 138),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0D000000))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 14, 2),
            child: relatedHeader(_relatedItems().length),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 6),
              children: [for (final m in items) _noteRow(m)],
            ),
          ),
        ],
      ),
    );
  }

  // 패널 상단: 지금 보고 있는(hover/선택) 메모.
  Widget _panelCurrent(String id) {
    final brief = _controller.noteBrief(id);
    if (brief == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: colorChip(brief['color'] as int),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              brief['preview'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11, color: Colors.black38),
                children: [
                  const TextSpan(text: '↑↓ 이동   ↵ 열기   esc 닫기'),
                  TextSpan(
                    text: '     6월 이후·6/1~6/10 기간',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 관련 표시 토글: 컴팩트(하단) ↔ 분할(우측 패널)
          Tooltip(
            message: _split ? '컴팩트 보기' : '분할 보기(관련 메모 옆에)',
            child: InkWell(
              onTap: _toggleSplit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _split
                      ? Icons.vertical_split_outlined
                      : Icons.horizontal_split_outlined,
                  size: 16,
                  color: _split ? _accent : Colors.black38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelStatus() {
    final ready = _controller.hasSelectedModel;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.auto_awesome_rounded : Icons.psychology_outlined,
            size: 16,
            color: _accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ready
                  ? 'AI가 메모를 읽는 중 · ${_controller.indexedNotes}/${_controller.indexTotal}'
                  : '정확 검색만 사용 중 · AI 관련 검색 모델이 없습니다',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ),
          if (!ready)
            TextButton(
              onPressed: () async {
                await _hide();
                await _controller.openModels();
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('모델 받기'),
            ),
        ],
      ),
    );
  }
}
