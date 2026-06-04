import 'models/sticky.dart';

/// 완료한 할 일 한 건 (텍스트 + 완료 시각). 보고서 타임라인용.
class CompletedItem {
  final String text;
  final int ts; // 완료 시각 millis (completedAt ?? sticky.updatedAt)
  const CompletedItem(this.text, this.ts);

  Map<String, dynamic> toJson() => {'text': text, 'ts': ts};

  factory CompletedItem.fromJson(Map<String, dynamic> j) =>
      CompletedItem(j['text'] as String, j['ts'] as int);
}

/// 한 기간의 "내가 한 일" 요약 (로컬 집계, API 불필요).
class PeriodReport {
  final List<CompletedItem> completed; // 완료한 할 일 (완료 시각 내림차순)
  final List<String> open; // 아직 열린 할 일
  final int activeStickies; // 기간 내 수정된 스티커 수

  const PeriodReport({
    required this.completed,
    required this.open,
    required this.activeStickies,
  });

  Map<String, dynamic> toJson() => {
        'completed': completed.map((c) => c.toJson()).toList(),
        'open': open,
        'activeStickies': activeStickies,
      };

  factory PeriodReport.fromJson(Map<String, dynamic> j) => PeriodReport(
        completed: (j['completed'] as List)
            .map((e) => CompletedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        open: (j['open'] as List).cast<String>(),
        activeStickies: j['activeStickies'] as int,
      );
}

class ReportData {
  final PeriodReport week;
  final PeriodReport month;

  const ReportData({required this.week, required this.month});

  Map<String, dynamic> toJson() =>
      {'week': week.toJson(), 'month': month.toJson()};

  factory ReportData.fromJson(Map<String, dynamic> j) => ReportData(
        week: PeriodReport.fromJson(j['week'] as Map<String, dynamic>),
        month: PeriodReport.fromJson(j['month'] as Map<String, dynamic>),
      );
}

ReportData buildReport(List<Sticky> stickies, DateTime now) {
  PeriodReport forDays(int days) {
    final since = now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    final completed = <CompletedItem>[];
    final open = <String>[];
    var active = 0;
    for (final s in stickies) {
      if (s.updatedAt.millisecondsSinceEpoch >= since) active++;
      for (final b in s.blocks) {
        if (b is! TodoBlock) continue;
        if (b.text.trim().isEmpty) continue;
        if (b.checked) {
          // completedAt 없으면(시드/구버전 체크) sticky.updatedAt 으로 폴백 — 누락 방지.
          final t = b.completedAt ?? s.updatedAt.millisecondsSinceEpoch;
          if (t >= since) completed.add(CompletedItem(b.text.trim(), t));
        } else {
          open.add(b.text.trim());
        }
      }
    }
    completed.sort((a, b) => b.ts.compareTo(a.ts)); // 최신 완료 먼저
    return PeriodReport(
        completed: completed, open: open, activeStickies: active);
  }

  return ReportData(week: forDays(7), month: forDays(30));
}
