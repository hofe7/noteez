import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../ipc.dart';

class ModelWindowApp extends StatelessWidget {
  const ModelWindowApp({super.key, required this.initialState});

  final Map<String, dynamic> initialState;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'AI 모델',
    theme: noteezTheme(),
    home: ModelWindow(initialState: initialState),
  );
}

class ModelWindow extends StatefulWidget {
  const ModelWindow({super.key, required this.initialState});

  final Map<String, dynamic> initialState;

  @override
  State<ModelWindow> createState() => _ModelWindowState();
}

class _ModelWindowState extends State<ModelWindow> {
  static const _main = MainChannel.instance;
  late Map<String, dynamic> _state = widget.initialState;
  final TextEditingController _search = TextEditingController();
  bool _requesting = false;
  bool _searching = false;
  bool _searched = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = const [];
  int _rejected = 0;

  List<Map<String, dynamic>> get _models =>
      (_state['models'] as List).cast<Map<String, dynamic>>();
  String? get _activeId => _state['activeId'] as String?;
  bool get _busy => _activeId != null;

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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await action();
      final latest = await _main.getModelState();
      if (mounted) setState(() => _state = latest);
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _findModels() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _searched = true;
      _searchError = null;
      _rejected = 0;
    });
    try {
      final result = await _main.searchModels(_search.text);
      if (!mounted) return;
      setState(() {
        _searchResults = ((result['models'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
        _rejected = result['rejected'] as int? ?? 0;
      });
    } catch (error) {
      if (mounted) setState(() => _searchError = _message(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openSource(Map<String, dynamic> model) async {
    final uri = Uri.tryParse(model['sourceUrl'] as String? ?? '');
    if (uri == null || uri.scheme != 'https') return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모델 페이지를 열 수 없습니다.')));
    }
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('PlatformException(error, ', '')
      .replaceFirst(RegExp(r', null, null\)$'), '')
      .replaceFirst('Bad state: ', '');

  Future<void> _remove(Map<String, dynamic> model) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('다운로드한 모델을 삭제할까요?'),
        content: Text('${model['name']} 파일만 삭제합니다. 메모는 그대로 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (yes == true) await _run(() => _main.deleteModel(model['id'] as String));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        children: [
          const Text(
            'AI 연결 모델',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '모델만 Hugging Face에서 내려받고, 메모와 임베딩은 이 Mac 밖으로 보내지 않습니다.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink2),
          ),
          const SizedBox(height: 20),
          if (_state['error'] case final String error) ...[
            _errorBanner(error),
            const SizedBox(height: 12),
          ],
          for (final model in _models) ...[
            _modelCard(model),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          _searchSection(),
        ],
      ),
    ),
  );

  Widget _modelCard(Map<String, dynamic> model) {
    final id = model['id'] as String;
    final installed = model['installed'] == true;
    final selected = model['selected'] == true;
    final active = _activeId == id;
    final progress = (_state['progress'] as num?)?.toDouble() ?? 0;
    final activity = _state['activity'] as String? ?? 'idle';
    final indexed = _state['indexed'] as int? ?? 0;
    final total = _state['indexTotal'] as int? ?? 0;
    final indexing = selected && total > 0 && indexed < total && !_busy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF9E8) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppColors.accent : const Color(0x16000000),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            model['name'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _badge(model['badge'] as String),
                        if (model['recommended'] == true) ...[
                          const SizedBox(width: 5),
                          _badge('추천', accent: true),
                        ],
                        if (model['verified'] == true) ...[
                          const SizedBox(width: 5),
                          _badge('검증됨'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      model['description'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.ink2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_size(model['downloadBytes'] as int)} · '
                            '${model['dimensions']}차원 · ${model['license']} · '
                            '${model['repository']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink3,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openSource(model),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                          ),
                          child: const Text(
                            '출처',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (installed)
                IconButton(
                  tooltip: '모델 삭제',
                  onPressed: _busy || _requesting ? null : () => _remove(model),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.ink3,
                ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    activity == 'verifying'
                        ? '파일 무결성 확인 중…'
                        : '다운로드 중 · ${(progress * 100).floor()}%',
                    style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                  ),
                ),
                TextButton(
                  onPressed: () => _main.cancelModelDownload(),
                  child: const Text('취소'),
                ),
              ],
            ),
          ] else if (indexing) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: total == 0 ? null : indexed / total),
            const SizedBox(height: 7),
            Text(
              '메모 다시 읽는 중 · $indexed/$total',
              style: const TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: selected
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '사용 중',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : installed
                  ? OutlinedButton(
                      onPressed: _busy || _requesting
                          ? null
                          : () => _run(
                              () => _main.selectModel(id),
                              successMessage: '모델을 바꿨습니다 · 메모를 다시 읽는 중입니다.',
                            ),
                      child: const Text('이 모델 사용'),
                    )
                  : FilledButton.icon(
                      onPressed: _busy || _requesting
                          ? null
                          : () => _run(
                              () => _main.downloadModel(id),
                              successMessage: '다운로드 완료 · 메모를 다시 읽는 중입니다.',
                            ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('다운로드'),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, {bool accent = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: accent ? const Color(0x24F1B82D) : const Color(0x0C000000),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: accent ? AppColors.ink : AppColors.ink3,
      ),
    ),
  );

  String _size(int bytes) => '${(bytes / 1024 / 1024).round()}MB';

  Widget _errorBanner(String error) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x22C62828)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            error,
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
          ),
        ),
      ],
    ),
  );

  Widget _searchSection() {
    final knownIds = {for (final model in _models) model['id']};
    final results = _searchResults
        .where((model) => !knownIds.contains(model['id']))
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x12000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 19,
                color: AppColors.ink3,
              ),
              SizedBox(width: 8),
              Text(
                'Hugging Face에서 찾기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'multilingual-e5 계열 중 고정 버전·LFS 해시·XLM-R ONNX 구성이 확인된 모델만 표시합니다. 저장소 코드는 실행하지 않습니다.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.ink3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  enabled: !_searching,
                  onSubmitted: (_) => _findModels(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '예: multilingual-e5 int8',
                    prefixIcon: Icon(Icons.search_rounded, size: 19),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _findModels,
                child: _searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('검색'),
              ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 9),
            Text(
              _searchError!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          if (!_searching && _searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (results.isEmpty)
              Text(
                '호환 모델이 위 목록에 이미 있습니다${_rejected > 0 ? ' · $_rejected개 제외' : ''}.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
            for (final model in results) _searchResult(model),
          ] else if (_searched && !_searching && _searchError == null) ...[
            const SizedBox(height: 9),
            const Text(
              '현재 검색어에서 Noteez 호환성이 확인된 모델이 없습니다.',
              style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchResult(Map<String, dynamic> model) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0x07000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model['name'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${model['repository']} · ${_size(model['downloadBytes'] as int)} · '
                '${model['dimensions']}차원 · ${model['license']}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Hugging Face 출처',
          onPressed: () => _openSource(model),
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
        ),
        FilledButton.icon(
          onPressed: _busy || _requesting
              ? null
              : () => _run(
                  () => _main.installSearchModel(model),
                  successMessage: '다운로드 완료 · 메모를 다시 읽는 중입니다.',
                ),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('받기'),
        ),
      ],
    ),
  );
}
