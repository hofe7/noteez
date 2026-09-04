import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../ipc.dart';

class BackupWindowApp extends StatelessWidget {
  const BackupWindowApp({super.key, required this.initialState});

  final Map<String, dynamic> initialState;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '백업',
    theme: noteezTheme(),
    home: BackupWindow(initialState: initialState),
  );
}

class BackupWindow extends StatefulWidget {
  const BackupWindow({super.key, required this.initialState});

  final Map<String, dynamic> initialState;

  @override
  State<BackupWindow> createState() => _BackupWindowState();
}

class _BackupWindowState extends State<BackupWindow> {
  static const _main = MainChannel.instance;
  late Map<String, dynamic> _state = widget.initialState;
  bool _creating = false;
  String? _restoringPath;

  List<Map<String, dynamic>> get _backups =>
      ((_state['backups'] as List?) ?? const []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    WindowController.fromCurrentEngine().then((controller) {
      controller.setWindowMethodHandler((call) async {
        if (call.method == ToWindow.refresh && mounted) {
          setState(() {
            _state =
                jsonDecode(call.arguments as String) as Map<String, dynamic>;
          });
        }
        return null;
      });
    });
  }

  Future<void> _createBackup() async {
    if (_creating || _restoringPath != null) return;
    setState(() => _creating = true);
    try {
      final state = await _main.createAutomaticBackup();
      if (!mounted) return;
      setState(() => _state = state);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 백업을 만들었습니다.')));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> backup) async {
    if (_creating || _restoringPath != null || backup['isValid'] != true) {
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 시점으로 되돌릴까요?'),
        content: Text(
          '${_date(backup['createdAt'] as int)} 백업으로 메모를 복원합니다.\n\n'
          '현재 상태도 먼저 자동 백업되며, 복원이 끝나면 Noteez가 다시 시작됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복원하고 재시작'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    final path = backup['path'] as String;
    setState(() => _restoringPath = path);
    try {
      await _main.restoreBackupPath(path);
      await _main.restartForRestore();
    } catch (error) {
      _showError(error);
      if (mounted) setState(() => _restoringPath = null);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error
        .toString()
        .replaceFirst('PlatformException(error, ', '')
        .replaceFirst(RegExp(r', null, null\)$'), '')
        .replaceFirst('FormatException: ', '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '자동 백업',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '실행할 때와 외부 메모를 가져오기 전에 저장하며, 최근 10개를 보관합니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _creating || _restoringPath != null
                    ? null
                    : _createBackup,
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, size: 18),
                label: const Text('지금 백업'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.accentTint(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentTint(0.22)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.accentInk,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    '복원 직전의 현재 상태도 자동으로 남기므로 다시 되돌릴 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.accentInk,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _main.openBackupFolder,
                  child: const Text('Finder에서 보기'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_backups.isEmpty)
            _emptyState()
          else
            for (var index = 0; index < _backups.length; index++) ...[
              _backupCard(_backups[index], latest: index == 0),
              if (index != _backups.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    ),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.borderStrong),
    ),
    child: const Column(
      children: [
        Icon(Icons.history_rounded, size: 36, color: AppColors.ink3),
        SizedBox(height: 12),
        Text('아직 자동 백업이 없습니다.'),
        SizedBox(height: 4),
        Text(
          '지금 백업을 누르거나 다음 실행 후 다시 확인해 주세요.',
          style: TextStyle(fontSize: 12, color: AppColors.ink2),
        ),
      ],
    ),
  );

  Widget _backupCard(Map<String, dynamic> backup, {required bool latest}) {
    final path = backup['path'] as String;
    final valid = backup['isValid'] == true;
    final restoring = _restoringPath == path;
    final noteCount = backup['noteCount'] as int?;
    final imageCount = backup['imageCount'] as int?;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: valid ? AppColors.accentTint(0.13) : AppColors.fill2,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              valid ? Icons.history_rounded : Icons.error_outline_rounded,
              size: 20,
              color: valid ? AppColors.accentInk : AppColors.ink3,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _date(backup['createdAt'] as int),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (latest && valid) ...[
                      const SizedBox(width: 7),
                      _badge('최신'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  valid
                      ? '메모 ${noteCount ?? 0}개 · 이미지 ${imageCount ?? 0}개 · '
                            '${_size(backup['sizeBytes'] as int)}'
                      : '읽을 수 없는 백업 · ${_size(backup['sizeBytes'] as int)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: valid ? AppColors.ink2 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: !valid || _creating || _restoringPath != null
                ? null
                : () => _restore(backup),
            child: restoring
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('복원'),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.accentTint(0.16),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.accentInk,
      ),
    ),
  );
}

String _date(int milliseconds) {
  final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}. ${value.month}. ${value.day}.  '
      '${two(value.hour)}:${two(value.minute)}';
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
