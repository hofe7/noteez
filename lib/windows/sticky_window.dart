import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../date_util.dart';
import '../editor/note_editor.dart';
import '../ipc.dart';
import '../models/sticky.dart';
import '../sticky_palette.dart';

class StickyWindowApp extends StatelessWidget {
  final Sticky initial;
  final bool focusOnOpen;
  const StickyWindowApp(
      {super.key, required this.initial, this.focusOnOpen = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(useMaterial3: true),
      home: StickyWindow(initial: initial, focusOnOpen: focusOnOpen),
    );
  }
}

class StickyWindow extends StatefulWidget {
  final Sticky initial;
  final bool focusOnOpen; // 검색/소환으로 열렸으면 바로 편집 포커스
  const StickyWindow(
      {super.key, required this.initial, this.focusOnOpen = false});

  @override
  State<StickyWindow> createState() => _StickyWindowState();
}

class _StickyWindowState extends State<StickyWindow> with WindowListener {
  static const _main =
      WindowMethodChannel(kMainChannel, mode: ChannelMode.unidirectional);
  static const double _width = 244; // 기본 너비
  static const double _headerH = 30;
  static const double _maxBodyH = 520;

  double _winW = _width; // 현재 창 너비(사용자가 넓히면 유지) — 접기/펴기에도 보존

  final GlobalKey<NoteEditorState> _editorKey = GlobalKey<NoteEditorState>();

  late Sticky _s = widget.initial;
  Timer? _saveTimer;
  Timer? _resizeTimer;
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();
  double? _lastWindowH;
  double? _expandedH; // 펴진 상태의 마지막 높이(접었다 펼 때 복원)
  List<Map<String, dynamic>> _links = const []; // 승인된 연결
  Map<String, dynamic>? _suggestion; // 제안(미승인) {id, preview, full, score}
  bool _sugExpanded = false; // 제안 펼쳐서 전체 내용 보기
  bool _linksExpanded = false; // 연결 목록 펼치기 (기본은 "연결 N"으로 접음)
  bool _hovering = false;
  bool _showColors = false;
  bool _userSized = false; // 사용자가 창 크기 직접 바꾸면 자동 맞춤 끔

  static bool _isFreshEmpty(Sticky s) =>
      s.blocks.length == 1 && s.blocks.first.text.isEmpty;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 메인→이 창 단일 메시지 채널: 'focusEditor' 오면 에디터 끝에 커서.
    WindowController.fromCurrentEngine().then((c) {
      c.setWindowMethodHandler((call) async {
        if (call.method == 'focusEditor' && mounted) {
          _editorKey.currentState?.focusEnd();
        }
        // 전체 보기에서 '서랍에 넣기' → 메인이 상태 갱신 후 창만 닫으라고 요청.
        if (call.method == 'requestClose') {
          _saveTimer?.cancel();
          await windowManager.close();
        }
        return null;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchConnection();
      if (_s.pinned) windowManager.setAlwaysOnTop(true);
    });
    // 시작 시 임베딩이 아직이면 제안이 비어있으니, 잠시 후 한 번 더 조회.
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _fetchConnection();
    });
  }

  // 사용자가 창 크기를 직접 바꾸면(우리 setSize 와 다른 높이) 자동 맞춤 중단.
  @override
  void onWindowResized() async {
    final sz = await windowManager.getSize();
    if (!mounted) return;
    _winW = sz.width; // 사용자가 너비를 바꿨으면 반영(우리 setSize는 같은 값이라 무해)
    if (_lastWindowH != null && (sz.height - _lastWindowH!).abs() > 8) {
      _userSized = true;
      if (!_s.collapsed) _expandedH = sz.height; // 수동 크기도 기억
    }
  }

  Future<void> _setH(double h) async {
    _lastWindowH = h;
    await windowManager.setSize(Size(_winW, h)); // 너비는 현재 값 유지(접기/펴기 불변)
  }

  void _togglePin() {
    final p = !_s.pinned;
    windowManager.setAlwaysOnTop(p);
    _apply(_s.copyWith(pinned: p));
  }

  Future<void> _fetchConnection() async {
    try {
      final r = await _main.invokeMethod('getConnection', _s.id);
      if (!mounted) return;
      final map = (r is String) ? jsonDecode(r) as Map<String, dynamic> : null;
      setState(() {
        _links = map == null
            ? const []
            : (map['links'] as List).cast<Map<String, dynamic>>();
        _suggestion = map?['suggestion'] as Map<String, dynamic>?;
        _sugExpanded = false;
      });
    } catch (_) {/* 연결 기능 비활성/오류 → 표시 안 함 */}
  }

  Future<void> _acceptLink(String otherId) async {
    await _main.invokeMethod('linkStickies', jsonEncode({'a': _s.id, 'b': otherId}));
    await _fetchConnection();
  }

  @override
  void onWindowMoved() async {
    final pos = await windowManager.getPosition();
    _s = _s.copyWith(x: pos.dx, y: pos.dy, updatedAt: DateTime.now());
    _persist();
  }

  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      await _main.invokeMethod('updateSticky', jsonEncode(_s.toJson()));
      await _fetchConnection(); // 편집 반영 후 관련 메모 갱신
    });
  }

  void _apply(Sticky next) {
    setState(() => _s = next.copyWith(updatedAt: DateTime.now()));
    _persist();
  }

  // 에디터가 바뀔 때마다: 블록 갱신 + 저장(디바운스) + 창 높이 재조정.
  // NoteEditor는 자기 표시를 직접 관리하므로 setState 불필요(키로 상태 보존).
  void _onEditorChanged(List<Block> blocks) {
    _s = _s.copyWith(blocks: blocks, updatedAt: DateTime.now());
    _persist();
    _scheduleResize();
  }

  // ── 창 높이를 내용에 맞춤 ──────────────────────────────────
  void _scheduleResize() {
    if (_userSized) return; // 사용자가 직접 키운 창은 건드리지 않음
    WidgetsBinding.instance.addPostFrameCallback((_) {
      double target;
      if (_s.collapsed) {
        target = _headerH;
      } else {
        final bodyH = _bodyKey.currentContext?.size?.height ?? 0;
        final footerH = _footerKey.currentContext?.size?.height ?? 0;
        target = _headerH + (bodyH + footerH).clamp(0.0, _maxBodyH);
        _expandedH = target; // 펴진 높이 기억
      }
      if (_lastWindowH != null && (_lastWindowH! - target).abs() <= 0.5) return;
      _lastWindowH = target;
      // 네이티브 setSize 는 비싸서 디바운스. 글자/블록은 즉시 뜨고 창은 살짝 뒤에.
      _resizeTimer?.cancel();
      _resizeTimer = Timer(const Duration(milliseconds: 70), () {
        windowManager.setSize(Size(_winW, target)); // 너비 유지, 높이만 맞춤
      });
    });
  }

  // 창 안 인라인 색 선택 (작은 창이라 팝업 대신).
  Widget _colorRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          for (var i = 0; i < StickyPalette.colors.length; i++)
            GestureDetector(
              onTap: () {
                _apply(_s.copyWith(colorIndex: i));
                setState(() => _showColors = false);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: StickyPalette.of(i),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == _s.colorIndex ? Colors.black54 : Colors.black12,
                    width: i == _s.colorIndex ? 2 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleCollapse() async {
    final collapsing = !_s.collapsed;
    _apply(_s.copyWith(collapsed: collapsing));
    if (collapsing) {
      await _setH(_headerH); // 헤더만
    } else if (_expandedH != null && _expandedH! > _headerH + 4) {
      await _setH(_expandedH!); // 접기 전 크기로 복원
    }
  }

  // 닫기(보관): 데이터 유지, 창만 닫음. 검색/연결/그래프로 다시 소환 가능.
  Future<void> _close() async {
    _saveTimer?.cancel();
    await _main.invokeMethod('closeSticky', _s.id);
    await windowManager.close();
  }

  // 삭제: 영구 제거(soft delete).
  Future<void> _delete() async {
    _saveTimer?.cancel();
    await _main.invokeMethod('deleteSticky', _s.id);
    await windowManager.close();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _saveTimer?.cancel();
    _resizeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleResize();
    return CallbackShortcuts(
      bindings: {
        // ⌘. : 접기/펴기 토글 (편집 중에도 동작 — 블록 필드가 안 쓰는 키라 위로 전파)
        const SingleActivator(LogicalKeyboardKey.period, meta: true):
            _toggleCollapse,
      },
      child: MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: Container(
        decoration: BoxDecoration(
          color: StickyPalette.of(_s.colorIndex),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            if (!_s.collapsed)
              // 항상 바닥-고정 레이아웃: 내용은 위(스크롤), 푸터는 창 바닥.
              // 드래그 리사이즈 중에도 실시간으로 푸터가 따라옴.
              Expanded(
                child: Column(
                  children: [
                    // 본문 빈 영역(글자 아래)을 눌러도 마지막 줄에 커서가 가도록.
                    // TextField는 자기 탭을 먼저 가져가므로 빈 곳 탭만 여기로 옴.
                    Expanded(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.text, // 빈 곳도 I-beam
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // 본문 빈 영역 탭 → 에디터 끝에 커서. (에디터 위 탭은 Quill이 가져감)
                          onTap: () => _editorKey.currentState?.focusEnd(),
                          child: SingleChildScrollView(
                            child: Padding(
                              key: _bodyKey,
                              padding: const EdgeInsets.fromLTRB(12, 6, 10, 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_showColors) _colorRow(),
                                  NoteEditor(
                                    key: _editorKey,
                                    initial: _s.blocks,
                                    autofocus: widget.focusOnOpen ||
                                        _isFreshEmpty(_s),
                                    accent: StickyPalette.ink(_s.colorIndex),
                                    onChanged: _onEditorChanged,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_footerChildren().isNotEmpty)
                      Padding(
                        key: _footerKey,
                        padding: const EdgeInsets.fromLTRB(12, 2, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _footerChildren(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  List<Widget> _footerChildren() => [
        if (_links.isNotEmpty) _linksWidget(),
        if (_suggestion != null) _suggestionRow(_suggestion!),
      ];

  Widget _header() {
    return ClipRRect(
      borderRadius: _s.collapsed
          ? BorderRadius.circular(10)
          : const BorderRadius.vertical(top: Radius.circular(10)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          height: _headerH,
          color: StickyPalette.header(_s.colorIndex),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: _s.collapsed
                    ? Text(
                        _s.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87),
                      )
                    : Text(
                        relativeDate(_s.createdAt, DateTime.now()),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38),
                      ),
              ),
              if (_s.pinned && !_hovering)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.push_pin, size: 13, color: Colors.black38),
                ),
              if (_hovering) ...[
                _iconBtn(Icons.palette_outlined,
                    () => setState(() => _showColors = !_showColors)),
                _iconBtn(
                    _s.collapsed ? Icons.unfold_more : Icons.unfold_less,
                    _toggleCollapse,
                    _s.collapsed ? '펴기  ⌘.' : '접기  ⌘.'),
                _iconBtn(_s.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    _togglePin),
                _iconBtn(Icons.delete_outline, _delete),
                _iconBtn(Icons.close, _close), // × = 닫기(보관)
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 연결: 기본은 "🔗 연결 N" 한 줄로 접음(메모가 주인공). 누르면 목록 펼침.
  Widget _linksWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _linksExpanded = !_linksExpanded),
            child: Row(
              children: [
                const Icon(Icons.link, size: 13, color: Colors.black54),
                const SizedBox(width: 5),
                Text('연결 ${_links.length}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
                Icon(_linksExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 15, color: Colors.black26),
              ],
            ),
          ),
        ),
        if (_linksExpanded)
          for (final lk in _links) _linkRow(lk),
      ],
    );
  }

  // 펼친 연결 한 줄. 클릭하면 그 메모 창이 앞으로.
  Widget _linkRow(Map<String, dynamic> lk) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 18),
      child: InkWell(
        onTap: () => _main.invokeMethod('focusSticky', lk['id']),
        borderRadius: BorderRadius.circular(4),
        child: Text(
          lk['preview'] as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }

  // 제안(미승인): 조용히. 펼치면 전체 내용 확인 후 [연결]로 영속(그래프에 추가).
  Widget _suggestionRow(Map<String, dynamic> s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 12, color: Colors.black26),
              const SizedBox(width: 5),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _sugExpanded = !_sugExpanded),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '관련: ${s['preview']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                      ),
                      Icon(
                        _sugExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 15,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _linkPill(() => _acceptLink(s['id'] as String)),
            ],
          ),
        ),
        // 펼치면 관련 메모 전체 내용 — 보고 나서 연결 결정.
        if (_sugExpanded)
          Container(
            margin: const EdgeInsets.only(top: 6, left: 17),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (s['full'] as String?)?.isNotEmpty == true
                  ? s['full'] as String
                  : s['preview'] as String,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black54, height: 1.35),
            ),
          ),
      ],
    );
  }

  // [연결] 버튼 — 스티커 톤에 맞춘 중성 회색. (쨍한 색은 파스텔이랑 안 어울림)
  Widget _linkPill(VoidCallback onTap) {
    return Tooltip(
      message: '연결',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_link,
              size: 14, color: Colors.black.withValues(alpha: 0.55)),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, [String? tooltip]) {
    final btn = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: Colors.black54),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }
}
