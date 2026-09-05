import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'trash_dialog.dart';
import 'organize_dialog.dart';
import 'reference_list.dart';
import '../date_util.dart';
import '../ipc.dart';
import '../sticky_palette.dart';

/// 전체 보기: 라이브러리 창. 모든 메모(열림 + 서랍)를 묶음 + 그 외로 정리하고
/// 필터/정렬/상태로 추려서 본다. 검색 팔레트가 '빠른 찾기'라면 이건 '둘러보기·정리'.
class OverviewWindowApp extends StatelessWidget {
  final List<Map<String, dynamic>>
  notes; // {id,label,color,open,updatedAt,createdAt}
  final List<Map<String, dynamic>> edges; // {a,b}
  final List<Map<String, dynamic>> suggestedGroups; // {ids:[...],score}
  final List<Map<String, dynamic>> groups; // {id,name,collapsed,memberIds}
  final List<Map<String, dynamic>> referenceSuggestions;
  final String? notice;
  final bool modelReady;
  final int modelIndexed;
  final int modelIndexTotal;
  final String? fontFamily;
  const OverviewWindowApp({
    super.key,
    required this.notes,
    required this.edges,
    required this.suggestedGroups,
    this.groups = const [],
    this.referenceSuggestions = const [],
    this.notice,
    this.modelReady = true,
    this.modelIndexed = 0,
    this.modelIndexTotal = 0,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '전체 보기',
      theme: noteezTheme(fontFamily: fontFamily),
      home: OverviewWindow(
        notes: notes,
        edges: edges,
        suggestedGroups: suggestedGroups,
        groups: groups,
        referenceSuggestions: referenceSuggestions,
        notice: notice,
        modelReady: modelReady,
        modelIndexed: modelIndexed,
        modelIndexTotal: modelIndexTotal,
      ),
    );
  }
}

enum _Status { all, open, drawer }

enum _Sort { recent, created, name }

class OverviewWindow extends StatefulWidget {
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> edges;
  final List<Map<String, dynamic>> suggestedGroups;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> referenceSuggestions;
  final String? notice;
  final bool modelReady;
  final int modelIndexed;
  final int modelIndexTotal;
  const OverviewWindow({
    super.key,
    required this.notes,
    required this.edges,
    required this.suggestedGroups,
    this.groups = const [],
    this.referenceSuggestions = const [],
    this.notice,
    this.modelReady = true,
    this.modelIndexed = 0,
    this.modelIndexTotal = 0,
  });

  @override
  State<OverviewWindow> createState() => _OverviewWindowState();
}

class _OverviewWindowState extends State<OverviewWindow> {
  static const _main = MainChannel.instance;
  static const Color _accent = AppColors.accent; // 시그니처 허니 앰버

  final DateTime _now = DateTime.now();
  String _filter = '';
  _Status _status = _Status.all;
  _Sort _sort = _Sort.recent;

  // 메인이 push 하는 최신 데이터로 갱신 (창 껐다 켤 필요 없게).
  late List<Map<String, dynamic>> _notes = widget.notes;
  late List<Map<String, dynamic>> _suggestedGroups = widget.suggestedGroups;
  late List<Map<String, dynamic>> _groups = widget.groups;
  late String? _notice = widget.notice;
  late bool _modelReady = widget.modelReady;
  late int _modelIndexed = widget.modelIndexed;
  late int _modelIndexTotal = widget.modelIndexTotal;
  bool _relations = false;
  late List<Map<String, dynamic>> _edges = widget.edges;
  late List<Map<String, dynamic>> _referenceSuggestions =
      widget.referenceSuggestions;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WindowController.fromCurrentEngine().then((c) {
      c.setWindowMethodHandler((call) async {
        if (call.method == ToWindow.refresh && mounted) {
          final m =
              jsonDecode(call.arguments as String) as Map<String, dynamic>;
          setState(() {
            _notes = (m['notes'] as List).cast<Map<String, dynamic>>();
            _edges = ((m['edges'] as List?) ?? const [])
                .cast<Map<String, dynamic>>();
            _referenceSuggestions =
                ((m['referenceSuggestions'] as List?) ?? const [])
                    .cast<Map<String, dynamic>>();
            _suggestedGroups = ((m['suggestedGroups'] as List?) ?? const [])
                .cast<Map<String, dynamic>>();
            _groups = ((m['groups'] as List?) ?? const [])
                .cast<Map<String, dynamic>>();
            if (m['notice'] is String) _notice = m['notice'] as String;
            _modelReady = m['modelReady'] as bool? ?? _modelReady;
            _modelIndexed = m['modelIndexed'] as int? ?? _modelIndexed;
            _modelIndexTotal = m['modelIndexTotal'] as int? ?? _modelIndexTotal;
          });
        }
        return null;
      });
    });
  }

  Future<void> _open(String id) => _main.focusSticky(id);
  Future<void> _drawer(String id) => _main.drawerSticky(id);

  bool _matches(Map<String, dynamic> n) {
    final t = _filter.trim().toLowerCase();
    final okText =
        t.isEmpty || (n['label'] as String).toLowerCase().contains(t);
    final okStatus = switch (_status) {
      _Status.all => true,
      _Status.open => n['open'] == true,
      _Status.drawer => n['open'] != true,
    };
    return okText && okStatus;
  }

  int _cmp(Map<String, dynamic> a, Map<String, dynamic> b) => switch (_sort) {
    _Sort.recent => (b['updatedAt'] as int).compareTo(a['updatedAt'] as int),
    _Sort.created => (b['createdAt'] as int).compareTo(a['createdAt'] as int),
    _Sort.name => (a['label'] as String).compareTo(b['label'] as String),
  };

  // 하이브리드 엔진이 계산한 읽기 전용 추천 묶음. 삭제된 id와 확정 묶음 id는
  // 방어적으로 한 번 더 제거한다.
  ({
    List<
      ({
        List<Map<String, dynamic>> members,
        List<String> reasons,
        String? title,
      })
    >
    clusters,
    Set<String> grouped,
  })
  _suggested(Set<String> confirmed) {
    final byId = {for (final n in _notes) n['id'] as String: n};
    final clusters =
        <
          ({
            List<Map<String, dynamic>> members,
            List<String> reasons,
            String? title,
          })
        >[];
    final grouped = <String>{};
    for (final raw in _suggestedGroups) {
      final ids = (raw['ids'] as List).cast<String>();
      final members = [
        for (final id in ids)
          if (!confirmed.contains(id) && !grouped.contains(id)) byId[id],
      ].whereType<Map<String, dynamic>>().toList();
      if (members.length < 2) continue;
      grouped.addAll(members.map((m) => m['id'] as String));
      clusters.add((
        members: members,
        reasons: ((raw['reasons'] as List?) ?? const []).cast<String>(),
        title: raw['title'] as String?,
      ));
    }
    return (clusters: clusters, grouped: grouped);
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final note in _notes) note['id'] as String: note};
    final manualIds = <String>{
      for (final group in _groups)
        ...((group['memberIds'] as List?) ?? const []).cast<String>(),
    };
    final visibleManual =
        <({Map<String, dynamic> group, List<Map<String, dynamic>> members})>[];
    for (final group in _groups) {
      final allMembers = [
        for (final id
            in ((group['memberIds'] as List?) ?? const []).cast<String>())
          byId[id],
      ].whereType<Map<String, dynamic>>().toList();
      final members = allMembers.where(_matches).toList()..sort(_cmp);
      if (members.isNotEmpty ||
          (allMembers.isEmpty &&
              _filter.trim().isEmpty &&
              _status == _Status.all)) {
        visibleManual.add((group: group, members: members));
      }
    }
    final suggested = _suggested(manualIds);
    final visibleSuggested = [
      for (final c in suggested.clusters)
        if (c.members.where(_matches).toList() case final m when m.isNotEmpty)
          (
            title: c.title ?? c.members.first['label'] as String,
            members: m..sort(_cmp),
            ids: c.members.map((n) => n['id'] as String).toList(),
            reasons: c.reasons,
          ),
    ];
    final ungrouped =
        _notes
            .where(
              (n) =>
                  !manualIds.contains(n['id']) &&
                  !suggested.grouped.contains(n['id']) &&
                  _matches(n),
            )
            .toList()
          ..sort(_cmp);
    final shown =
        visibleManual.fold<int>(0, (s, g) => s + g.members.length) +
        visibleSuggested.fold<int>(0, (s, c) => s + c.members.length) +
        ungrouped.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: _selectionMode ? _selectionBar() : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(
              _groups.length,
              suggested.clusters.length +
                  _groups.fold<int>(
                    0,
                    (sum, group) =>
                        sum + ((group['suggestions'] as List?)?.length ?? 0),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  side: const WidgetStatePropertyAll(
                    BorderSide(color: AppColors.border),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.accentTint(0.12)
                        : AppColors.fill,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.accentInk
                        : AppColors.ink2,
                  ),
                  textStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('묶음'),
                    icon: Icon(Icons.folder_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('관계'),
                    icon: Icon(Icons.link),
                  ),
                ],
                selected: {_relations},
                onSelectionChanged: (value) => setState(() {
                  _relations = value.single;
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              ),
            ),
            _controls(),
            if (!_modelReady || _modelIndexed < _modelIndexTotal)
              _modelBanner(),
            if (_notice != null) _noticeBanner(),
            const Divider(height: 1, color: AppColors.hair),
            Expanded(
              child: _relations
                  ? ReferenceList(
                      notes: _notes,
                      edges: _edges,
                      suggestions: _referenceSuggestions,
                      matches: _matches,
                    )
                  : (shown == 0 && visibleManual.isEmpty)
                  ? _empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        for (final entry in visibleManual) ...[
                          _manualGroupCard(entry.group, entry.members),
                          const SizedBox(height: 14),
                        ],
                        for (final c in visibleSuggested) ...[
                          _clusterCard(
                            c.members,
                            suggestedTitle: c.title,
                            actionIds: c.ids,
                            reasons: c.reasons,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (ungrouped.isNotEmpty || manualIds.isNotEmpty)
                          _ungroupedSection(ungrouped),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noticeBanner() => Container(
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: AppColors.accentTint(0.13),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.accentTint(0.28)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: _accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _notice!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _notice = null),
          tooltip: '닫기',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 16),
        ),
      ],
    ),
  );

  Widget _modelBanner() => Container(
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: AppColors.accentTint(0.09),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.accentTint(0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 16, color: _accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _modelReady
                ? '관련 메모를 다시 읽는 중 · $_modelIndexed/$_modelIndexTotal'
                : '키워드·작성 시점으로 추천 중 · AI 모델을 받으면 의미까지 비교해요.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
          ),
        ),
        if (!_modelReady)
          TextButton(onPressed: _main.openModels, child: const Text('모델 받기')),
      ],
    ),
  );

  Widget _header(int manualCount, int suggestionCount) {
    final total = _notes.length;
    final drawer = _notes.where((n) => n['open'] != true).length;
    final liveIds = _notes.map((n) => n['id']).toSet();
    Set<String> pairKeys(List<Map<String, dynamic>> pairs) => {
      for (final pair in pairs)
        if (pair['a'] != pair['b'] &&
            liveIds.contains(pair['a']) &&
            liveIds.contains(pair['b']))
          jsonEncode([pair['a'] as String, pair['b'] as String]..sort()),
    };
    final saved = pairKeys(_edges);
    final relatedCount = pairKeys(
      _referenceSuggestions,
    ).difference(saved).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '전체 보기',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const TrashDialog(),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('휴지통'),
              ),
              if (!_relations)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectionMode = !_selectionMode;
                    if (!_selectionMode) _selectedIds.clear();
                  }),
                  icon: Icon(
                    _selectionMode
                        ? Icons.close_rounded
                        : Icons.checklist_rounded,
                    size: 16,
                  ),
                  label: Text(_selectionMode ? '취소' : '선택'),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _relations
                ? '메모 $total개 · 참고 ${saved.length}개 · 관련 추천 $relatedCount개'
                : '메모 $total개 · 내 묶음 $manualCount개 · 추천 $suggestionCount개 · 참고 ${saved.length}개 · 서랍 $drawer개',
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 18, 10),
      child: Column(
        children: [
          Row(
            children: [
              // 필터 입력
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x07000000),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0x0F000000)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16, color: Colors.black38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _filter = v),
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '메모 거르기…',
                            hintStyle: TextStyle(color: Colors.black26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_relations) ...[const SizedBox(width: 10), _sortMenu()],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusChip('전체', _Status.all),
              const SizedBox(width: 7),
              _statusChip('열림', _Status.open),
              const SizedBox(width: 7),
              _statusChip('서랍', _Status.drawer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortMenu() {
    String label(_Sort s) => switch (s) {
      _Sort.recent => '최근 수정',
      _Sort.created => '만든 날짜',
      _Sort.name => '이름',
    };
    return PopupMenuButton<_Sort>(
      initialValue: _sort,
      onSelected: (s) => setState(() => _sort = s),
      tooltip: '정렬',
      itemBuilder: (_) => [
        for (final s in _Sort.values)
          PopupMenuItem(value: s, child: Text(label(s))),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x07000000),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0x0F000000)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: Colors.black45,
            ),
            const SizedBox(width: 5),
            Text(
              label(_sort),
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, _Status s) {
    final on = _status == s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _status = s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? _accent.withValues(alpha: 0.16) : const Color(0x07000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on
                ? _accent.withValues(alpha: 0.4)
                : const Color(0x0F000000),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
            color: on ? AppColors.accentInk : AppColors.ink2,
          ),
        ),
      ),
    );
  }

  Future<String?> _askGroupName({
    required String title,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    controller.selection = TextSelection.collapsed(offset: initial.length);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: '묶음 이름',
            hintText: '예: 이번 분기 준비',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    final name = result?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  Future<void> _createGroupFromIds(
    Iterable<String> ids, {
    String initialName = '',
  }) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.length < 2) return;
    final name = await _askGroupName(title: '새 묶음 만들기', initial: initialName);
    if (name == null) return;
    final previous = {for (final id in uniqueIds) id: _groupContaining(id)};
    final groupId = await _main.createNoteGroup(name, uniqueIds);
    if (groupId != null && mounted) {
      _offerUndo('‘$name’ 묶음을 만들었어요.', () async {
        await _main.restoreNoteMemberships(previous, deleteGroupId: groupId);
      });
    }
    if (mounted) {
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  Future<void> _renameGroup(Map<String, dynamic> group) async {
    final oldName = group['name'] as String;
    final name = await _askGroupName(title: '묶음 이름 바꾸기', initial: oldName);
    if (name != null) {
      await _main.renameNoteGroup(group['id'] as String, name);
      if (mounted) {
        _offerUndo('묶음 이름을 ‘$name’(으)로 바꿨어요.', () async {
          await _main.renameNoteGroup(group['id'] as String, oldName);
        });
      }
    }
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('묶음을 삭제할까요?'),
        content: const Text('메모는 삭제되지 않고 ‘그 외’로 돌아갑니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('묶음 삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final id = group['id'] as String;
      final name = group['name'] as String;
      final members = ((group['memberIds'] as List?) ?? const [])
          .cast<String>();
      final collapsed = group['collapsed'] == true;
      final position = group['position'] as int?;
      await _main.deleteNoteGroup(id);
      if (mounted) {
        _offerUndo('‘$name’ 묶음을 삭제했어요. 메모는 그대로예요.', () async {
          await _main.createNoteGroup(
            name,
            members,
            requestedId: id,
            collapsed: collapsed,
            position: position,
          );
        });
      }
    }
  }

  String? _groupContaining(String noteId) {
    for (final group in _groups) {
      final ids = ((group['memberIds'] as List?) ?? const []).cast<String>();
      if (ids.contains(noteId)) return group['id'] as String;
    }
    return null;
  }

  String _groupName(String groupId) {
    for (final group in _groups) {
      if (group['id'] == groupId) return group['name'] as String;
    }
    return '묶음';
  }

  void _offerUndo(String message, Future<void> Function() undo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () {
            undo();
          },
        ),
      ),
    );
  }

  Future<void> _moveNote(String noteId, String groupId) async {
    final previous = _groupContaining(noteId);
    if (previous == groupId) return;
    await _main.assignNotesToGroup(groupId, [noteId]);
    if (!mounted) return;
    _offerUndo('‘${_groupName(groupId)}’ 묶음으로 옮겼어요.', () async {
      if (previous == null) {
        await _main.removeNotesFromGroup([noteId]);
      } else {
        await _main.assignNotesToGroup(previous, [noteId]);
      }
    });
  }

  Future<void> _removeNoteFromGroup(String noteId) async {
    final previous = _groupContaining(noteId);
    if (previous == null) return;
    await _main.removeNotesFromGroup([noteId]);
    if (mounted) {
      _offerUndo('메모를 묶음에서 뺐어요.', () async {
        await _main.assignNotesToGroup(previous, [noteId]);
      });
    }
  }

  Widget _manualGroupCard(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> members,
  ) {
    final id = group['id'] as String;
    final collapsed = group['collapsed'] == true;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !((group['memberIds'] as List).cast<String>().contains(details.data)),
      onAcceptWithDetails: (details) => _moveNote(details.data, id),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? AppColors.surface
              : AppColors.accentTint(0.11),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: candidates.isEmpty ? AppColors.border : _accent,
          ),
          boxShadow: kCardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _main.setNoteGroupCollapsed(id, !collapsed),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 9),
                child: Row(
                  children: [
                    Icon(
                      collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.ink3,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        group['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _countBadge(members.length),
                    PopupMenuButton<String>(
                      tooltip: '묶음 메뉴',
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      onSelected: (value) {
                        if (value == 'rename') _renameGroup(group);
                        if (value == 'delete') _deleteGroup(group);
                        if (value == 'resetSuggestions') {
                          _main.resetGroupSuggestions(id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('이름 바꾸기')),
                        PopupMenuItem(value: 'delete', child: Text('묶음 삭제')),
                        PopupMenuItem(
                          value: 'resetSuggestions',
                          child: Text('숨긴 추가 추천 다시 보기'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!collapsed) ...[
              const Divider(height: 1, color: Color(0x0D000000)),
              for (final member in members) _noteRow(member),
              for (final suggestion
                  in ((group['suggestions'] as List?) ?? const []))
                _groupAddition(id, suggestion as Map<String, dynamic>),
            ],
          ],
        ),
      ),
    );
  }

  Widget _groupAddition(String groupId, Map<String, dynamic> suggestion) {
    final noteId = suggestion['noteId'] as String;
    final notes = _notes.where(
      (note) => note['id'] == noteId && _matches(note),
    );
    if (notes.isEmpty || _groupContaining(noteId) != null) {
      return const SizedBox.shrink();
    }
    final note = notes.first;
    final reasons = ((suggestion['reasons'] as List?) ?? const [])
        .cast<String>();
    return Container(
      key: ValueKey('group-addition-$groupId-$noteId'),
      color: AppColors.accentTint(0.06),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 묶음에 추가할까요?',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _open(noteId),
                  child: Text(
                    note['label'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _moveNote(noteId, groupId),
                child: const Text('추가'),
              ),
              IconButton(
                tooltip: '이 묶음에 추천하지 않기',
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => _main.dismissGroupSuggestion(noteId, groupId),
              ),
            ],
          ),
          if (reasons.isNotEmpty)
            Text(
              reasons.join(' · '),
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
            ),
        ],
      ),
    );
  }

  Widget _selectionBar() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hair)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('${_selectedIds.length}개 선택'),
          TextButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        OrganizeDialog(noteIds: _selectedIds.toList()),
                  ),
            child: const Text('묶음에 넣기·빼기'),
          ),
          FilledButton.icon(
            onPressed: _selectedIds.length < 2
                ? null
                : () => _createGroupFromIds(_selectedIds),
            icon: const Icon(Icons.create_new_folder_outlined, size: 17),
            label: const Text('묶음 만들기'),
          ),
        ],
      ),
    ),
  );

  Widget _clusterCard(
    List<Map<String, dynamic>> members, {
    String? suggestedTitle,
    List<String> actionIds = const [],
    List<String> reasons = const [],
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentTint(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentTint(0.28)),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 8),
            child: Row(
              children: [
                ...[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: _accent,
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    '${suggestedTitle ?? members.first['label']} 관련',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...[
                  Text(
                    '추천',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentInk.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _clusterAction(
                    Icons.done_all_rounded,
                    '묶음으로 확정',
                    () => _createGroupFromIds(
                      actionIds,
                      initialName:
                          '${suggestedTitle ?? members.first['label']} 관련',
                    ),
                  ),
                  _clusterAction(
                    Icons.close_rounded,
                    '이 추천 숨기기',
                    () => _main.dismissSuggestions(actionIds),
                  ),
                  const SizedBox(width: 4),
                ],
                _countBadge(members.length),
              ],
            ),
          ),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
              child: Text(
                reasons.join(' · '),
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
            ),
          const Divider(height: 1, color: Color(0x0D000000)),
          for (final m in members) _noteRow(m),
        ],
      ),
    );
  }

  Widget _clusterAction(IconData icon, String tooltip, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 15, color: AppColors.ink3),
          ),
        ),
      );

  Widget _moveMenu(String noteId) {
    final current = _groupContaining(noteId);
    return PopupMenuButton<String>(
      tooltip: '묶음으로 이동',
      icon: const Icon(
        Icons.drive_file_move_outline,
        size: 16,
        color: Colors.black38,
      ),
      onSelected: (value) {
        if (value == '__none__') {
          _removeNoteFromGroup(noteId);
        } else {
          _moveNote(noteId, value);
        }
      },
      itemBuilder: (_) => [
        for (final group in _groups)
          PopupMenuItem(
            value: group['id'] as String,
            child: Row(
              children: [
                Icon(
                  current == group['id']
                      ? Icons.check_rounded
                      : Icons.folder_outlined,
                  size: 16,
                  color: current == group['id'] ? _accent : AppColors.ink3,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(group['name'] as String)),
              ],
            ),
          ),
        if (current != null) const PopupMenuDivider(),
        if (current != null)
          const PopupMenuItem(value: '__none__', child: Text('묶음에서 빼기')),
      ],
    );
  }

  Widget _ungroupedSection(List<Map<String, dynamic>> notes) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) => _removeNoteFromGroup(details.data),
      builder: (context, candidates, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Text(
              candidates.isEmpty ? '그 외' : '여기에 놓아 묶음에서 빼기',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: candidates.isEmpty ? Colors.black45 : _accent,
                letterSpacing: -0.2,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: candidates.isEmpty
                  ? const Color(0x05000000)
                  : AppColors.accentTint(0.09),
              borderRadius: BorderRadius.circular(14),
              border: candidates.isEmpty ? null : Border.all(color: _accent),
            ),
            child: Column(children: [for (final m in notes) _noteRow(m)]),
          ),
        ],
      ),
    );
  }

  // 메모 한 줄. 행 클릭=열기/소환. 끝에 서랍 넣기/꺼내기 버튼.
  // 닫힘(서랍)은 칩·텍스트만 흐리게, 버튼은 또렷하게.
  Widget _noteRow(Map<String, dynamic> m) {
    final closed = m['open'] != true;
    final id = m['id'] as String;
    final selected = _selectedIds.contains(id);
    return InkWell(
      onTap: () => _selectionMode
          ? setState(() {
              selected ? _selectedIds.remove(id) : _selectedIds.add(id);
            })
          : _open(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            if (_selectionMode) ...[
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => setState(() {
                  selected ? _selectedIds.remove(id) : _selectedIds.add(id);
                }),
              ),
              const SizedBox(width: 3),
            ] else ...[
              Draggable<String>(
                data: id,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: kCardShadow,
                    ),
                    child: Text(
                      m['label'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                child: const Tooltip(
                  message: '묶음으로 드래그',
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 16,
                    color: Colors.black26,
                  ),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Opacity(
              opacity: closed ? 0.5 : 1.0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: StickyPalette.of(m['color'] as int),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x14000000)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: closed ? 0.55 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m['label'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (closed) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 11,
                            color: Colors.black38,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      relativeDate(
                        DateTime.fromMillisecondsSinceEpoch(
                          m['updatedAt'] as int,
                        ),
                        _now,
                      ),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!_selectionMode && _groups.isNotEmpty) _moveMenu(id),
            if (!_selectionMode) _rowAction(id, closed),
          ],
        ),
      ),
    );
  }

  // 끝 버튼: 열림→서랍에 넣기, 서랍→꺼내기. (행 탭과 별개로 동작)
  Widget _rowAction(String id, bool closed) {
    return Tooltip(
      message: closed ? '꺼내기' : '서랍에 넣기',
      child: InkWell(
        onTap: () => closed ? _open(id) : _drawer(id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            closed ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
            size: 16,
            color: closed ? _accent : Colors.black38,
          ),
        ),
      ),
    );
  }

  Widget _countBadge(int n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: _accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$n',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _accent,
      ),
    ),
  );

  Widget _empty() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        '조건에 맞는 메모가 없어요.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.black45),
      ),
    ),
  );
}
