import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../ipc.dart';

/// Saved references and unconfirmed suggestions share a browsing surface,
/// but actions only change reference links, never group membership.
class ReferenceList extends StatefulWidget {
  const ReferenceList({
    super.key,
    required this.notes,
    required this.edges,
    required this.suggestions,
    required this.matches,
  });
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> edges;
  final List<Map<String, dynamic>> suggestions;
  final bool Function(Map<String, dynamic>) matches;

  @override
  State<ReferenceList> createState() => _ReferenceListState();
}

class _ReferenceListState extends State<ReferenceList> {
  final _pending = <String>{};
  String _key(Map<String, dynamic> pair) =>
      jsonEncode([pair['a'] as String, pair['b'] as String]..sort());

  Future<void> _act(Map<String, dynamic> pair, String action) async {
    final key = _key(pair);
    if (_pending.contains(key)) return;
    setState(() => _pending.add(key));
    try {
      final a = pair['a'] as String, b = pair['b'] as String;
      switch (action) {
        case 'keep':
          await MainChannel.instance.linkStickies(a, b);
        case 'remove':
          await MainChannel.instance.unlinkStickies(a, b);
        case 'dismiss':
          await MainChannel.instance.dismissSuggestions([a, b]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('관계를 변경하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = {for (final n in widget.notes) n['id'] as String: n};
    List<Map<String, dynamic>> valid(List<Map<String, dynamic>> source) {
      final seen = <String>{};
      return [
        for (final pair in source)
          if (pair['a'] != pair['b'] &&
              notes.containsKey(pair['a']) &&
              notes.containsKey(pair['b']) &&
              seen.add(_key(pair)))
            pair,
      ];
    }

    final saved = valid(widget.edges);
    final savedKeys = saved.map(_key).toSet();
    final suggested = valid(
      widget.suggestions,
    ).where((pair) => !savedKeys.contains(_key(pair))).toList();
    bool matches(Map<String, dynamic> pair) =>
        widget.matches(notes[pair['a']]!) || widget.matches(notes[pair['b']]!);
    final shownSaved = saved.where(matches).toList();
    final shownSuggested = suggested.where(matches).toList();

    Widget card(Map<String, dynamic> pair, {required bool suggestion}) {
      final busy = _pending.contains(_key(pair));
      Widget note(String id) => TextButton.icon(
        onPressed: () async {
          try {
            await MainChannel.instance.focusSticky(id);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('메모를 열지 못했습니다. 다시 시도해 주세요.')),
              );
            }
          }
        },
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: AppColors.ink,
        ),
        icon: const Icon(Icons.description_outlined, size: 16),
        label: Text(
          notes[id]!['label'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(pair['a'] as String),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.swap_vert, size: 18, color: AppColors.ink3),
              ),
            ),
            note(pair['b'] as String),
            if (suggestion && ((pair['reasons'] as List?) ?? []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  (pair['reasons'] as List).join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (suggestion) ...[
                  TextButton(
                    onPressed: busy ? null : () => _act(pair, 'dismiss'),
                    child: const Text('추천 숨기기'),
                  ),
                  FilledButton.tonal(
                    onPressed: busy ? null : () => _act(pair, 'keep'),
                    child: const Text('참고로 유지'),
                  ),
                ] else
                  TextButton(
                    onPressed: busy ? null : () => _act(pair, 'remove'),
                    child: const Text('참고 관계 해제'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text(
          '메모 제목을 누르면 열립니다. 참고 관계는 묶음 소속을 바꾸지 않습니다.',
          style: TextStyle(fontSize: 12, color: AppColors.ink3),
        ),
        const SizedBox(height: 16),
        Text(
          '저장한 참고 관계 ${saved.length}개',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (shownSaved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              saved.isEmpty
                  ? '저장한 참고 관계가 없습니다. 아래 추천을 살펴보세요.'
                  : '현재 필터에 맞는 참고 관계가 없습니다.',
            ),
          ),
        for (final pair in shownSaved) card(pair, suggestion: false),
        const SizedBox(height: 12),
        Text(
          '관련 메모 추천 ${suggested.length}개',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (shownSuggested.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              suggested.isEmpty
                  ? '현재 기준에 맞는 관련 메모 추천이 없습니다.'
                  : '현재 필터에 맞는 추천이 없습니다.',
            ),
          ),
        for (final pair in shownSuggested) card(pair, suggestion: true),
      ],
    );
  }
}
