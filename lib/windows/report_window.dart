import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
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
      theme: noteezTheme(),
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
  static const Color _accent = AppColors.accent; // 시그니처 허니 앰버

  _Period _period = _Period.month;
  final DateTime _now = DateTime.now();
  bool _copied = false; // "복사됨" 토스트
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

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
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
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
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: AppColors.ink)),
                      const SizedBox(height: 3),
                      Text(_subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink3)),
                    ],
                  ),
                  const Spacer(),
                  _copyButton(),
                ],
              ),
            ),
            // ── 기간 선택 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Segmented<_Period>(
                  value: _period,
                  onChanged: (p) => setState(() => _period = p),
                  items: const [
                    (_Period.week, '주'),
                    (_Period.month, '월'),
                    (_Period.quarter, '분기'),
                  ],
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
            const Divider(height: 1, color: AppColors.hair),
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
          _copyToast(),
        ],
      ),
    );
  }

  // 복사 버튼 (Material IconButton 대체) — 톤 맞춘 작은 알약.
  Widget _copyButton() {
    return Tooltip(
      message: '복사',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: _asText()));
          _copyTimer?.cancel();
          setState(() => _copied = true);
          _copyTimer = Timer(const Duration(milliseconds: 1300),
              () => mounted ? setState(() => _copied = false) : null);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, size: 15, color: AppColors.ink2),
              SizedBox(width: 6),
              Text('복사',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.ink2,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // "복사됨" 토스트 — 하단 중앙에서 부드럽게 페이드.
  Widget _copyToast() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 26,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _copied ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xF23A3429),
                borderRadius: BorderRadius.circular(20),
                boxShadow: kCardShadow,
              ),
              child: const Text('보고서 복사됨',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
            ),
          ),
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
        color: AppColors.hair,
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
