/// 한국어 상대 날짜 표기. 오늘/어제/N일 전/M월 D일/YYYY.M.D
String relativeDate(DateTime d, DateTime now) {
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return '오늘';
  if (diff == 1) return '어제';
  if (diff < 7) return '$diff일 전';
  if (d.year == now.year) return '${d.month}월 ${d.day}일';
  return '${d.year}.${d.month}.${d.day}';
}
