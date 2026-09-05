import 'package:flutter/material.dart';

import '../ipc.dart';

class TrashDialog extends StatefulWidget {
  const TrashDialog({super.key});

  @override
  State<TrashDialog> createState() => _TrashDialogState();
}

class _TrashDialogState extends State<TrashDialog> {
  final _main = MainChannel.instance;
  List<Map<String, dynamic>>? _notes;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await _main.getTrash();
      if (mounted) {
        setState(() {
          _notes = notes;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '휴지통을 불러오지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _act(String id, {required bool permanent}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (permanent) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('영구 삭제할까요?'),
            content: const Text(
              '이 메모는 휴지통에서 복원할 수 없게 됩니다. 기존 백업에는 남아 있을 수 있습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('영구 삭제'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _main.permanentlyDeleteTrashed(id);
      } else {
        await _main.restoreTrashed(id);
      }
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '처리하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('휴지통'),
    content: SizedBox(
      width: 600,
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('삭제한 메모는 검색·추천에서 제외됩니다.\n복원하면 묶음과 알림 없이 서랍으로 돌아갑니다.'),
          const SizedBox(height: 12),
          if (_error != null)
            Row(
              children: [
                Expanded(child: Text(_error!)),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          Expanded(
            child: _notes == null
                ? (_error == null
                      ? const Center(child: CircularProgressIndicator())
                      : const SizedBox())
                : _notes!.isEmpty
                ? const Center(child: Text('휴지통이 비어 있습니다.'))
                : ListView.separated(
                    itemCount: _notes!.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final note = _notes![index];
                      final text = (note['text'] as String).trim();
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        note['deletedAt'] as int,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.isEmpty ? '텍스트 없는 메모' : text,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${date.year}.${date.month}.${date.day} 삭제',
                                ),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(
                                        note['id'] as String,
                                        permanent: false,
                                      ),
                                child: const Text('복원'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(
                                        note['id'] as String,
                                        permanent: true,
                                      ),
                                child: const Text('영구 삭제'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}
