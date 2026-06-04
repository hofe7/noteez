import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../date_util.dart';
import '../report.dart';

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
  bool _monthly = false;

  PeriodReport get _r => _monthly ? widget.data.month : widget.data.week;
  String get _periodLabel => _monthly ? '이번 달' : '이번 주';

  String _asText() {
    final r = _r;
    final b = StringBuffer()
      ..writeln('# $_periodLabel 내가 한 일')
      ..writeln()
      ..writeln('## 완료한 일 (${r.completed.length})');
    final now = DateTime.now();
    String? last;
    for (final c in r.completed) {
      final label = relativeDate(DateTime.fromMillisecondsSinceEpoch(c.ts), now);
      if (label != last) {
        b
          ..writeln()
          ..writeln('### $label');
        last = label;
      }
      b.writeln('- ${c.text}');
    }
    b
      ..writeln()
      ..writeln('## 열린 할 일 (${r.open.length})');
    for (final o in r.open) {
      b.writeln('- $o');
    }
    b
      ..writeln()
      ..writeln('활동한 메모: ${r.activeStickies}개');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
              child: Row(
                children: [
                  const Text('내가 한 일',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('이번 주')),
                      ButtonSegment(value: true, label: Text('이번 달')),
                    ],
                    selected: {_monthly},
                    onSelectionChanged: (s) =>
                        setState(() => _monthly = s.first),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('활동한 메모 ${r.activeStickies}개',
                      style: const TextStyle(color: Colors.black54)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _asText()));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('복사됨'),
                              duration: Duration(seconds: 1)),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('복사'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  _completedSection(r.completed),
                  const SizedBox(height: 18),
                  _section('열린 할 일', r.open, Icons.radio_button_unchecked,
                      Colors.orange.shade700),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 완료한 일: 완료 날짜별 그룹 (타임라인). 회고/평가에 그대로 쓰기 좋게.
  Widget _completedSection(List<CompletedItem> items) {
    final now = DateTime.now();
    final groups = <String, List<String>>{};
    final order = <String>[];
    for (final c in items) {
      final label =
          relativeDate(DateTime.fromMillisecondsSinceEpoch(c.ts), now);
      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(c.text);
    }
    final green = Colors.green.shade600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('완료한 일 (${items.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('없음', style: TextStyle(color: Colors.black38)),
          )
        else
          ...order.map((label) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45)),
                  ),
                  ...groups[label]!.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 8),
                              child:
                                  Icon(Icons.check_circle, size: 16, color: green),
                            ),
                            Expanded(
                                child: Text(t,
                                    style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                      )),
                ],
              )),
      ],
    );
  }

  Widget _section(String title, List<String> items, IconData icon, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title (${items.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('없음', style: TextStyle(color: Colors.black38)),
          )
        else
          ...items.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(icon, size: 16, color: c),
                    ),
                    Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
      ],
    );
  }
}
