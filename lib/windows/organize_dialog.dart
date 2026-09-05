import 'package:flutter/material.dart';
import '../ipc.dart';
import '../app_theme.dart';

/// The same explicit organization controls for a memo and a bulk selection.
class OrganizeDialog extends StatefulWidget {
  const OrganizeDialog({super.key, required this.noteIds, this.onDone});
  final List<String> noteIds;
  final VoidCallback? onDone;

  @override
  State<OrganizeDialog> createState() => _OrganizeDialogState();
}

class _OrganizeDialogState extends State<OrganizeDialog> {
  final _main = MainChannel.instance;
  final _search = TextEditingController();
  final _name = TextEditingController();
  Map<String, dynamic>? _data;
  bool _links = false;
  bool _creating = false;
  bool _busy = false;
  String? _error;
  String? _message;
  Future<void> Function()? _undo;
  List<String> get _ids => widget.noteIds.toSet().toList();
  List<Map<String, dynamic>> _rows(String key) =>
      ((_data?[key] as List?) ?? const []).cast<Map<String, dynamic>>();
  String? _membership(String id) {
    for (final group in _rows('groups')) {
      if ((group['memberIds'] as List).contains(id)) {
        return group['id'] as String;
      }
    }
    return null;
  }

  Map<String, String?> get _previous => {
    for (final id in _ids) id: _membership(id),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _main.getOrganization();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '목록을 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Refresh before writing, so undo captures the current memberships.
      _data = await _main.getOrganization();
      final live = _rows('notes').map((n) => n['id']).toSet();
      if (!_ids.every(live.contains)) throw StateError('메모가 삭제되었습니다.');
      await action();
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '변경하지 못했어요. 목록을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(String? groupId, {String? newName}) => _run(() async {
    final previous = _previous;
    String? created;
    if (newName != null) {
      created = await _main.createNoteGroup(newName, _ids);
      if (created == null) throw StateError('묶음 생성 실패');
    } else if (groupId == null) {
      await _main.removeNotesFromGroup(_ids);
    } else {
      if (!_rows('groups').any((g) => g['id'] == groupId)) {
        throw StateError('묶음이 삭제되었습니다.');
      }
      await _main.assignNotesToGroup(groupId, _ids);
    }
    _undo = () =>
        _main.restoreNoteMemberships(previous, deleteGroupId: created);
    _message = newName != null
        ? '‘$newName’ 묶음을 만들었어요.'
        : groupId == null
        ? '묶음에서 뺐어요.'
        : '선택한 묶음에 넣었어요.';
    _name.clear();
    _creating = false;
  });

  bool _linked(String other) => _rows('edges').any(
    (e) =>
        (e['a'] == _ids.single && e['b'] == other) ||
        (e['b'] == _ids.single && e['a'] == other),
  );

  Future<void> _toggleLink(String other) => _run(() async {
    final linked = _linked(other);
    if (linked) {
      await _main.unlinkStickies(_ids.single, other);
    } else {
      await _main.linkStickies(_ids.single, other);
    }
    _undo = () => linked
        ? _main.linkStickies(_ids.single, other)
        : _main.unlinkStickies(_ids.single, other);
    _message = linked ? '참고 연결을 해제했어요.' : '참고 메모로 연결했어요.';
  });

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final groups = _rows('groups')
        .where((g) => (g['name'] as String).toLowerCase().contains(query))
        .toList();
    final notes =
        (_ids.length == 1 ? _rows('notes') : <Map<String, dynamic>>[])
            .where(
              (n) =>
                  !_ids.contains(n['id']) &&
                  '${n['label']} ${n['text'] ?? ''}'.toLowerCase().contains(
                    query,
                  ),
            )
            .toList()
          ..sort((a, b) {
            final linked =
                (_linked(b['id'] as String) ? 1 : 0) -
                (_linked(a['id'] as String) ? 1 : 0);
            return linked != 0
                ? linked
                : (a['label'] as String).compareTo(b['label'] as String);
          });
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        title: Text(_ids.length == 1 ? '연결·묶음' : '${_ids.length}개 메모 정리'),
        content: SizedBox(
          width: 420,
          height: (height * .65).clamp(100, 480).toDouble(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_ids.length == 1)
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    side: WidgetStatePropertyAll(
                      BorderSide(color: AppColors.border),
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
                      label: Text('연결'),
                      icon: Icon(Icons.link),
                    ),
                  ],
                  selected: {_links},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _links = value.single;
                          _search.clear();
                        }),
                ),
              const SizedBox(height: 8),
              if (_ids.length == 1 && _data != null)
                Text(
                  _rows('notes')
                          .where((n) => n['id'] == _ids.single)
                          .map((n) => n['label'] as String)
                          .firstOrNull ??
                      '삭제된 메모',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              Text(
                _links
                    ? '함께 참고할 메모를 직접 찾아 연결하세요.'
                    : '메모는 한 묶음에 속해요. 다른 묶음을 고르면 이동해요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextField(
                controller: _search,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: _links ? '제목·내용으로 메모 찾기' : '묶음 찾기',
                ),
              ),
              if (_error != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              if (_message != null)
                Row(
                  children: [
                    Expanded(child: Text(_message!)),
                    TextButton(
                      onPressed: _busy || _undo == null
                          ? null
                          : () => _run(() async {
                              await _undo!();
                              _undo = null;
                              _message = '실행 취소했어요.';
                            }),
                      child: const Text('실행 취소'),
                    ),
                  ],
                ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: _data == null
                    ? const Center(child: Text('목록을 불러오는 중…'))
                    : ListView(
                        children: _links
                            ? [
                                if (notes.isEmpty)
                                  const ListTile(title: Text('찾는 메모가 없어요.')),
                                for (final note in notes)
                                  ListTile(
                                    title: Text(
                                      note['label'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _toggleLink(
                                              note['id'] as String,
                                            ),
                                      child: Text(
                                        _linked(note['id'] as String)
                                            ? '해제'
                                            : '연결',
                                      ),
                                    ),
                                  ),
                              ]
                            : [
                                ListTile(
                                  leading: const Icon(
                                    Icons.folder_off_outlined,
                                  ),
                                  title: const Text('묶음에서 빼기'),
                                  enabled:
                                      !_busy &&
                                      _previous.values.any((v) => v != null),
                                  onTap: () => _assign(null),
                                ),
                                if (groups.isEmpty)
                                  const ListTile(
                                    title: Text('묶음이 없어요. 아래에서 만들 수 있어요.'),
                                  ),
                                for (final group in groups)
                                  ListTile(
                                    leading: Icon(
                                      _ids.every(
                                            (id) =>
                                                _membership(id) == group['id'],
                                          )
                                          ? Icons.check_circle_outline
                                          : Icons.folder_outlined,
                                    ),
                                    title: Text(group['name'] as String),
                                    subtitle: Text(
                                      '${(group['memberIds'] as List).length}개 메모',
                                    ),
                                    enabled:
                                        !_busy &&
                                        !_ids.every(
                                          (id) =>
                                              _membership(id) == group['id'],
                                        ),
                                    onTap: () => _assign(group['id'] as String),
                                  ),
                              ],
                      ),
              ),
              if (!_links) ...[
                const SizedBox(height: 8),
                if (_creating)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          enabled: !_busy,
                          autofocus: true,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: '새 묶음 이름',
                            counterText: '',
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (value) {
                            if (!_busy && value.trim().isNotEmpty) {
                              _assign(null, newName: value.trim());
                            }
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: _busy || _name.text.trim().isEmpty
                            ? null
                            : () => _assign(null, newName: _name.text.trim()),
                        child: const Text('만들기'),
                      ),
                      IconButton(
                        tooltip: '새 묶음 취소',
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _creating = false;
                                _name.clear();
                              }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _creating = true),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('새 묶음 만들기'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : widget.onDone ?? () => Navigator.pop(context),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }
}
