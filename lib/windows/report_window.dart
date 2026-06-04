import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../date_util.dart';
import '../report.dart';

enum _Period { week, month, quarter }

class ReportWindowApp extends StatelessWidget {
  final ReportData data;
  const ReportWindowApp({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '리포트',
      theme: ThemeData(useMaterial3: true),
      home: ReportWindow(data: data),
    );
  }
}

class ReportWindow extends StatefulWidget {
  final ReportData data;
  const ReportWindow({super.key, required this.data});

  @override
  State<ReportWindow> createState() => _ReportWindowState();
}

class _ReportWindowState extends State<ReportWindow> {
  static const Color _accent = Color(0xFFB58236); // 보고서 액센트(차분한 앰버)
  static const Color _bg = Color(0xFFFBFAF6);

  _Period _period = _Period.month;
  final DateTime _now = DateTime.now();

  PeriodReport get _r => switch (_period) {
        _Period.week => widget.data.week,
        _Period.month => widget.data.month,
        _Period.quarter => widget.data.quarter,
      };

  // 헤더 부제: 기간을 사람이 읽는 표현으로.
  String get _subtitle => switch (_period) {
        _Period.week => '${_now.year}년 ${_now.month}월 · 이번 주',
        _Period.month => '${_now.year}년 ${_now.month}월',
        _Period.quarter => '${_now.year}년 ${(_now.month - 1) ~/ 3 + 1}분기',
      };

  // 완료 항목을 기간에 맞는 단위로 묶을 때 쓰는 라벨.
  String _bucketOf(DateTime d) => switch (_period) {
        _Period.week => relativeDate(d, _now),
        _Period.month => '${d.month}월 ${(d.day - 1) ~/ 7 + 1}주차',
        _Period.quarter => '${d.month}월',
      };

  // 완료 항목 → 버킷 라벨별 그룹(최신 먼저 순서 유지).
  ({List<String> order, Map<String, List<String>> groups}) _bucketed() {
    final order = <String>[];
    final groups = <String, List<String>>{};
    for (final c in _r.completed) {
      final label = _bucketOf(DateTime.fromMillisecondsSinceEpoch(c.ts));
      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(c.text);
    }
    return (order: order, groups: groups);
  }

  String _asText() {
    final r = _r;
    final b = StringBuffer()
      ..writeln('# 내가 한 일 · $_subtitle')
      ..writeln()
      ..writeln('완료 ${r.completed.length} · 진행 중 ${r.open.length} · 활동한 메모 ${r.activeStickies}')
      ..writeln()
      ..writeln('## 완료한 일');
    final bk = _bucketed();
    if (bk.order.isEmpty) b.writeln('_없음_');
    for (final label in bk.order) {
      b
        ..writeln()
        ..writeln('### $label');
      for (final t in bk.groups[label]!) {
        b.writeln('- $t');
      }
    }
    if (r.open.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## 진행 중');
      for (final o in r.open) {
        b.writeln('- $o');
      }
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final bk = _bucketed();
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 헤더: 제목 + 기간 + 복사 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('내가 한 일',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text(_subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black45)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '복사',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _asText()));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('보고서 복사됨'),
                              duration: Duration(seconds: 1)),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            // ── 기간 선택 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<_Period>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected)
                            ? _accent.withValues(alpha: 0.16)
                            : Colors.transparent),
                  ),
                  segments: const [
                    ButtonSegment(value: _Period.week, label: Text('주')),
                    ButtonSegment(value: _Period.month, label: Text('월')),
                    ButtonSegment(value: _Period.quarter, label: Text('분기')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),
              ),
            ),
            // ── 통계 스트립(보고서 대시보드 느낌) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  _stat('완료', r.completed.length, _accent),
                  _statDivider(),
                  _stat('진행 중', r.open.length, Colors.black54),
                  _statDivider(),
                  _stat('활동한 메모', r.activeStickies, Colors.black54),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x11000000)),
            // ── 본문 ──
            Expanded(
              child: r.completed.isEmpty && r.open.isEmpty
                  ? _empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      children: [
                        _completed(bk),
                        if (r.open.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _inProgress(r.open),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int n, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$n',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        color: const Color(0x11000000),
      );

  // 완료한 일: 기간 단위로 묶어 "성과 목록"처럼. 체크박스 아이콘 없이.
  Widget _completed(({List<String> order, Map<String, List<String>> groups}) bk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('완료한 일'),
        const SizedBox(height: 10),
        if (bk.order.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('이 기간에 완료한 일이 없어요.',
                style: TextStyle(color: Colors.black38)),
          )
        else
          for (final label in bk.order) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                          letterSpacing: -0.2)),
                  const SizedBox(width: 8),
                  Text('${bk.groups[label]!.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _accent)),
                ],
              ),
            ),
            for (final t in bk.groups[label]!) _achievement(t),
          ],
      ],
    );
  }

  // 성과 한 줄: 작은 앰버 점 + 텍스트. (todo 체크마크 대신)
  Widget _achievement(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 11, left: 2),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                color: _accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(t,
                style: const TextStyle(
                    fontSize: 14.5, color: Colors.black87, height: 1.35)),
          ),
        ],
      ),
    );
  }

  // 진행 중: 부차적·차분하게.
  Widget _inProgress(List<String> open) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('진행 중'),
        const SizedBox(height: 8),
        for (final o in open)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5, right: 11, left: 1),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 1.5),
                  ),
                ),
                Expanded(
                  child: Text(o,
                      style: const TextStyle(
                          fontSize: 13.5, color: Colors.black54, height: 1.3)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      );

  Widget _empty() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, size: 30, color: Colors.black26),
            SizedBox(height: 10),
            Text('이 기간엔 기록이 없어요',
                style: TextStyle(color: Colors.black38, fontSize: 14)),
          ],
        ),
      );
}
