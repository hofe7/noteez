/// 한국어 날짜 질의 파서. 검색어가 날짜 표현이면 구간을 반환, 아니면 null.
/// start/end 는 [start, end) 반열린 구간이며 각각 null이면 그 방향으로 열림.
///   - 6월 이후 / 6/3 부터  → start만
///   - 어제 이전 / 6월 까지  → end만
///   - 6/1 ~ 6/10          → 양쪽
///   - 오늘 / 지난주 / 6월   → 그 기간 전체
class DateRange {
  final DateTime? start; // 포함
  final DateTime? end; // 미포함
  const DateRange(this.start, this.end);

  bool contains(DateTime d) =>
      (start == null || !d.isBefore(start!)) &&
      (end == null || d.isBefore(end!));
}

DateRange? parseDateQuery(String query, DateTime now) {
  var q = query.trim();
  if (q.isEmpty) return null;

  final today = _day(now);

  // "최근 N일/주/일주일" — 오늘 포함 과거 N일.
  final recent = RegExp(r'^최근\s*(\d+)?\s*(일|주|일주일|주일)$').firstMatch(q);
  if (recent != null) {
    final unit = recent.group(2)!;
    var n = int.tryParse(recent.group(1) ?? '') ?? 1;
    if (unit.contains('주')) n *= 7;
    return DateRange(
        today.subtract(Duration(days: n - 1)), today.add(const Duration(days: 1)));
  }

  // 범위: "A ~ B" / "A - B" / "A 부터 B 까지"
  final tilde = q.split(RegExp(r'\s*[~∼\-]\s*|\s*부터\s*'));
  if (tilde.length == 2) {
    final a = _span(tilde[0].replaceAll('까지', '').trim(), now);
    final b = _span(tilde[1].replaceAll('까지', '').trim(), now);
    if (a != null && b != null) {
      var end = b.end;
      // 끝이 시작보다 빠르면 M/D 미래→작년 롤백이 잘못 걸린 것 → 같은 해로 보정.
      if (!end.isAfter(a.start)) {
        end = DateTime(end.year + 1, end.month, end.day);
      }
      return DateRange(a.start, end);
    }
    if (a != null && tilde[1].trim().isEmpty) return DateRange(a.start, null);
  }

  // 접미사: 이후 / 부터 / 이전 / 까지
  for (final suf in const ['이후', '부터']) {
    if (q.endsWith(suf)) {
      final s = _span(q.substring(0, q.length - suf.length).trim(), now);
      if (s != null) return DateRange(s.start, null);
    }
  }
  if (q.endsWith('이전')) {
    final s = _span(q.substring(0, q.length - 2).trim(), now);
    if (s != null) return DateRange(null, s.start); // 그 기간 이전(미포함)
  }
  if (q.endsWith('까지')) {
    final s = _span(q.substring(0, q.length - 2).trim(), now);
    if (s != null) return DateRange(null, s.end); // 그 기간 끝까지(포함)
  }

  // 단일 기간
  final s = _span(q, now);
  return s == null ? null : DateRange(s.start, s.end);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 하나의 날짜 "기간" 토큰을 [start,end) 로. 매칭 안 되면 null.
({DateTime start, DateTime end})? _span(String token, DateTime now) {
  final q = token.trim();
  if (q.isEmpty) return null;
  final today = _day(now);
  ({DateTime start, DateTime end}) oneDay(DateTime d) =>
      (start: _day(d), end: _day(d).add(const Duration(days: 1)));

  switch (q) {
    case '오늘':
      return oneDay(today);
    case '어제':
      return oneDay(today.subtract(const Duration(days: 1)));
    case '그제':
    case '그저께':
      return oneDay(today.subtract(const Duration(days: 2)));
    case '이번 주':
    case '이번주':
      final mon = today.subtract(Duration(days: today.weekday - 1));
      return (start: mon, end: mon.add(const Duration(days: 7)));
    case '지난 주':
    case '지난주':
    case '저번 주':
    case '저번주':
      final mon = today.subtract(Duration(days: today.weekday - 1 + 7));
      return (start: mon, end: mon.add(const Duration(days: 7)));
    case '이번 달':
    case '이번달':
      return (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 1)
      );
    case '지난 달':
    case '지난달':
    case '저번 달':
    case '저번달':
      return (
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 1)
      );
  }

  // "N일 전"
  final ago = RegExp(r'^(\d+)\s*일\s*전$').firstMatch(q);
  if (ago != null) {
    return oneDay(today.subtract(Duration(days: int.parse(ago.group(1)!))));
  }

  // "N월" (그 달 전체)
  final mon = RegExp(r'^(\d{1,2})\s*월$').firstMatch(q);
  if (mon != null) {
    final mo = int.parse(mon.group(1)!);
    if (mo >= 1 && mo <= 12) {
      var year = now.year;
      if (DateTime(year, mo, 1).isAfter(today)) year -= 1; // 미래면 작년
      return (start: DateTime(year, mo, 1), end: DateTime(year, mo + 1, 1));
    }
  }

  // "M월 D일"
  final md = RegExp(r'^(\d{1,2})\s*월\s*(\d{1,2})\s*일?$').firstMatch(q);
  if (md != null) {
    return _ymd(now.year, int.parse(md.group(1)!), int.parse(md.group(2)!),
        today, oneDay,
        rollBack: true);
  }

  // "YYYY-MM-DD" / "YYYY.MM.DD" / "YYYY/MM/DD"
  final iso = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})$').firstMatch(q);
  if (iso != null) {
    return _ymd(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
        int.parse(iso.group(3)!), today, oneDay);
  }

  // "M/D" / "M.D" (연도 생략 → 올해, 미래면 작년)
  final slash = RegExp(r'^(\d{1,2})[/.](\d{1,2})$').firstMatch(q);
  if (slash != null) {
    return _ymd(now.year, int.parse(slash.group(1)!), int.parse(slash.group(2)!),
        today, oneDay,
        rollBack: true);
  }

  return null;
}

({DateTime start, DateTime end})? _ymd(
  int y,
  int mo,
  int dd,
  DateTime today,
  ({DateTime start, DateTime end}) Function(DateTime) oneDay, {
  bool rollBack = false,
}) {
  if (mo < 1 || mo > 12 || dd < 1 || dd > 31) return null;
  var d = DateTime(y, mo, dd);
  if (d.month != mo) return null; // 2월 30일 등 무효
  if (rollBack && d.isAfter(today)) d = DateTime(y - 1, mo, dd);
  return oneDay(d);
}
