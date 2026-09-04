import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../date_util.dart';
import '../editor/note_editor.dart';
import '../ipc.dart';
import '../models/sticky.dart';
import '../sticky_palette.dart';
import '../sticky_window_sizing.dart';

class StickyWindowApp extends StatelessWidget {
  final Sticky initial;
  final bool focusOnOpen;
  const StickyWindowApp({
    super.key,
    required this.initial,
    this.focusOnOpen = false,
  });

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
  const StickyWindow({
    super.key,
    required this.initial,
    this.focusOnOpen = false,
  });

  @override
  State<StickyWindow> createState() => _StickyWindowState();
}

class _StickyWindowState extends State<StickyWindow> with WindowListener {
  static const _main = MainChannel.instance;
  static const double _headerH = StickyWindowSizing.headerHeight;

  late double _winW; // 현재 창 너비(사용자가 넓히면 유지) — 접기/펴기에도 보존

  final GlobalKey<NoteEditorState> _editorKey = GlobalKey<NoteEditorState>();

  late Sticky _s = widget.initial;
  Timer? _saveTimer;
  Timer? _resizeTimer;
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();
  double? _lastWindowW;
  double? _lastWindowH;
  double? _expandedH; // 펴진 상태의 마지막 높이(접었다 펼 때 복원)
  List<Map<String, dynamic>> _links = const []; // 승인된 연결
  Map<String, dynamic>? _suggestion; // 제안 {id, preview, full, score, reasons}
  bool _sugExpanded = false; // 제안 펼쳐서 전체 내용 보기
  bool _linksExpanded = false; // 연결 목록 펼치기 (기본은 "연결 N"으로 접음)
  bool _hovering = false;
  bool _showColors = false;
  bool _showReminder = false; // 리마인더 프리셋 피커 표시
  bool _userSized = false; // 사용자가 창 크기 직접 바꾸면 자동 맞춤 끔

  static bool _isFreshEmpty(Sticky s) =>
      s.blocks.length == 1 && s.blocks.first.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _winW = _s.width;
    _lastWindowW = _winW;
    _lastWindowH = _s.collapsed ? _headerH : _s.height;
    _expandedH = _s.height;
    _userSized = StickyWindowSizing.hasSavedManualSize(_s);
    windowManager.addListener(this);
    // 메인→이 창 단일 메시지 채널: 'focusEditor' 오면 에디터 끝에 커서.
    WindowController.fromCurrentEngine().then((c) {
      c.setWindowMethodHandler((call) async {
        if (call.method == ToWindow.focusEditor && mounted) {
          _editorKey.currentState?.focusEnd();
        }
        // 전체 보기에서 '서랍에 넣기' → 메인이 상태 갱신 후 창만 닫으라고 요청.
        if (call.method == ToWindow.requestClose) {
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

  // 사용자가 창 크기를 직접 바꾸면 자동 맞춤을 중단하고 다음 실행에도 복원한다.
  @override
  void onWindowResized() async {
    final sz = await windowManager.getSize();
    if (!mounted) return;
    final widthChanged =
        _lastWindowW != null && (sz.width - _lastWindowW!).abs() > 8;
    final heightChanged =
        _lastWindowH != null && (sz.height - _lastWindowH!).abs() > 8;
    _winW = sz.width;
    if (!widthChanged && !heightChanged) return;

    _resizeTimer?.cancel();
    _userSized = true;
    _lastWindowW = sz.width;
    _lastWindowH = sz.height;
    if (_s.collapsed) {
      _s = _s.copyWith(width: sz.width, updatedAt: DateTime.now());
    } else {
      _expandedH = sz.height;
      _s = _s.copyWith(
        width: sz.width,
        height: sz.height,
        updatedAt: DateTime.now(),
      );
    }
    _persist();
  }

  Future<void> _setH(double h) async {
    _lastWindowW = _winW;
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
      final r = await _main.getConnection(_s.id);
      if (!mounted) return;
      setState(() {
        _links = r.links;
        _suggestion = r.suggestion;
        _sugExpanded = false;
      });
    } catch (_) {
      /* 연결 기능 비활성/오류 → 표시 안 함 */
    }
  }

  Future<void> _acceptLink(String otherId) async {
    await _main.linkStickies(_s.id, otherId);
    await _fetchConnection();
  }

  Future<void> _removeLink(String otherId) async {
    await _main.unlinkStickies(_s.id, otherId);
    await _fetchConnection();
  }

  Future<void> _dismissSuggestion(String otherId) async {
    await _main.dismissSuggestions([_s.id, otherId]);
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
      await _main.updateSticky(_s);
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
        target = StickyWindowSizing.automaticExpandedHeight(
          bodyHeight: bodyH,
          footerHeight: footerH,
        );
        _expandedH = target; // 펴진 높이 기억
      }
      if (_lastWindowH != null && (_lastWindowH! - target).abs() <= 0.5) return;
      _lastWindowH = target;
      // 네이티브 setSize 는 비싸서 디바운스. 글자/블록은 즉시 뜨고 창은 살짝 뒤에.
      _resizeTimer?.cancel();
      _resizeTimer = Timer(const Duration(milliseconds: 70), () {
        if (_userSized) return;
        _lastWindowW = _winW;
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
    await _main.closeSticky(_s.id);
    await windowManager.close();
  }

  // 삭제: 영구 제거(soft delete).
  Future<void> _delete() async {
    _saveTimer?.cancel();
    await _main.deleteSticky(_s.id);
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
    final footerChildren = _footerChildren();
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
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                if (!_s.collapsed)
                  // 본문이 짧으면 푸터는 바닥에, 창이 너무 작거나 본문이 길면 전체가
                  // 자연스럽게 스크롤된다. 중첩 Column/Expanded의 순간 overflow를 피한다.
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.text,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _editorKey.currentState?.focusEnd(),
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                key: _bodyKey,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  6,
                                  10,
                                  4,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_showColors) _colorRow(),
                                    if (_showReminder) _reminderPicker(),
                                    NoteEditor(
                                      key: _editorKey,
                                      initial: _s.blocks,
                                      autofocus:
                                          widget.focusOnOpen ||
                                          _isFreshEmpty(_s),
                                      accent: StickyPalette.ink(_s.colorIndex),
                                      onChanged: _onEditorChanged,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: footerChildren.isEmpty
                                  ? const SizedBox.shrink()
                                  : Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        key: _footerKey,
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          2,
                                          10,
                                          12,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: footerChildren,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
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
    if (_s.remindAt != null) _reminderStatus(),
    if (_links.isNotEmpty) _linksWidget(),
    if (_suggestion != null) _suggestionRow(_suggestion!),
  ];

  // 리마인더 프리셋 (라벨, 시각). 발화 시 이 스티커가 desk 로 소환된다.
  List<(String, DateTime)> _remindPresets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    DateTime at(DateTime base, int h) =>
        DateTime(base.year, base.month, base.day, h);
    var evening = at(today, 18);
    if (!evening.isAfter(now)) evening = at(tomorrow, 18);
    var toMon = (8 - today.weekday) % 7;
    if (toMon == 0) toMon = 7; // 오늘이 월요일이면 다음 주 월요일
    return [
      ('1시간 후', now.add(const Duration(hours: 1))),
      ('오늘 저녁', evening),
      ('내일 아침', at(tomorrow, 9)),
      ('내일 저녁', at(tomorrow, 18)),
      ('다음 주', at(today.add(Duration(days: toMon)), 9)),
    ];
  }

  Future<void> _setReminder(DateTime dt) async {
    final ms = dt.millisecondsSinceEpoch;
    await _main.setReminder(_s.id, ms); // 메인이 예약(권위자)
    if (!mounted) return;
    setState(() {
      _s = _s.copyWith(remindAt: ms);
      _showReminder = false;
    });
  }

  Future<void> _clearReminder() async {
    await _main.clearReminder(_s.id);
    if (!mounted) return;
    setState(() {
      _s = _s.copyWith(clearRemind: true);
      _showReminder = false;
    });
  }

  // 미래 시각 표시: 오늘/내일/모레 HH:mm 또는 M/D HH:mm.
  String _fmtRemind(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final days = DateTime(dt.year, dt.month, dt.day).difference(d0).inDays;
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final day = switch (days) {
      0 => '오늘',
      1 => '내일',
      2 => '모레',
      _ => '${dt.month}/${dt.day}',
    };
    return '$day $hm';
  }

  Widget _reminderPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (label, dt) in _remindPresets())
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setReminder(dt),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x0F000000)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 설정된 리마인더 표시(+해제). 푸터에 노출.
  Widget _reminderStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.alarm, size: 13, color: StickyPalette.ink(_s.colorIndex)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _fmtRemind(_s.remindAt!),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _clearReminder,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 13, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }

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
                          color: Colors.black87,
                        ),
                      )
                    : Text(
                        relativeDate(_s.createdAt, DateTime.now()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
              ),
              if (_s.pinned && !_hovering)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.push_pin, size: 13, color: Colors.black38),
                ),
              if (_s.remindAt != null && !_hovering)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.alarm, size: 13, color: Colors.black38),
                ),
              if (_hovering) ...[
                _iconBtn(
                  _s.remindAt != null ? Icons.alarm_on : Icons.alarm_add,
                  () => setState(() => _showReminder = !_showReminder),
                  '리마인더',
                ),
                _iconBtn(
                  Icons.palette_outlined,
                  () => setState(() => _showColors = !_showColors),
                ),
                _iconBtn(
                  _s.collapsed ? Icons.unfold_more : Icons.unfold_less,
                  _toggleCollapse,
                  _s.collapsed ? '펴기  ⌘.' : '접기  ⌘.',
                ),
                _iconBtn(
                  _s.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  _togglePin,
                ),
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
                Text(
                  '연결 ${_links.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Icon(
                  _linksExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 15,
                  color: Colors.black26,
                ),
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
    final id = lk['id'] as String;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 18),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _main.focusSticky(id),
              borderRadius: BorderRadius.circular(4),
              child: Text(
                lk['preview'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          Tooltip(
            message: '연결 해제',
            child: InkWell(
              onTap: () => _removeLink(id),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.link_off, size: 13, color: Colors.black26),
              ),
            ),
          ),
        ],
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
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
              Tooltip(
                message: '이 추천 숨기기',
                child: InkWell(
                  onTap: () => _dismissSuggestion(s['id'] as String),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 13, color: Colors.black26),
                  ),
                ),
              ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (((s['reasons'] as List?) ?? const []).isNotEmpty) ...[
                  Text(
                    ((s['reasons'] as List).cast<String>()).join(' · '),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  (s['full'] as String?)?.isNotEmpty == true
                      ? s['full'] as String
                      : s['preview'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
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
          child: Icon(
            Icons.add_link,
            size: 14,
            color: Colors.black.withValues(alpha: 0.55),
          ),
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
