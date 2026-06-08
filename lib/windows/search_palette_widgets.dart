import 'package:flutter/material.dart';

import '../sticky_palette.dart';

/// 검색 팔레트의 순수 표현 위젯 모음 — 상태에 안 엮이고 파라미터만 받는다.
/// (상태 조정이 필요한 빌더는 search_palette.dart 의 State 에 남는다.)

/// 시그니처 액센트 = 따뜻한 허니 앰버 (포스트잇 파스텔과 한 식구).
const Color kPaletteAccent = Color(0xFFE8A33D);

/// 메모 색칩 (12×12 둥근 사각).
Widget colorChip(int colorIndex) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: StickyPalette.of(colorIndex),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x14000000)),
      ),
    );

/// "할 일 N" 작은 알약 배지.
Widget todoBadge(int n) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x0A000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checklist_rounded, size: 13, color: Colors.black38),
            const SizedBox(width: 4),
            Text('$n',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );

/// 개수 배지 (앰버).
Widget countBadge(int n) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kPaletteAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$n',
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: kPaletteAccent)),
    );

/// 구역 라벨 (정확 일치 / AI 관련 사이).
Widget sectionLabel(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: Colors.black26),
          const SizedBox(width: 6),
          Text(t,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black38,
                  letterSpacing: 0.2)),
        ],
      ),
    );

/// 결과 없음 빈 상태.
Widget emptyState() => const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 26, color: Colors.black26),
          SizedBox(height: 8),
          Text('결과가 없어요',
              style: TextStyle(color: Colors.black38, fontSize: 13)),
        ],
      ),
    );

/// "같은 묶음" 패널 헤더.
Widget relatedHeader(int count) => Row(
      children: [
        const Icon(Icons.bubble_chart_outlined, size: 14, color: Colors.black38),
        const SizedBox(width: 6),
        const Text('같은 묶음',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: -0.2)),
        const SizedBox(width: 6),
        countBadge(count),
      ],
    );

/// 공통 행 컨테이너: 선택 시 옅은 앰버 배경 + 둥근 모서리.
Widget paletteRow({
  required bool selected,
  required VoidCallback onTap,
  required VoidCallback onHover,
  required Widget child,
}) =>
    MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: selected
                ? kPaletteAccent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ),
    );

/// 미리보기 텍스트. 정확 일치면 검색어를 앰버로 강조.
Widget previewText(String preview, bool exact, String query) {
  const base = TextStyle(
      fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w400);
  final lq = query.trim().toLowerCase();
  final idx = (exact && lq.isNotEmpty) ? preview.toLowerCase().indexOf(lq) : -1;
  if (idx < 0) {
    return Text(preview,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
  }
  return Text.rich(
    TextSpan(style: base, children: [
      TextSpan(text: preview.substring(0, idx)),
      TextSpan(
          text: preview.substring(idx, idx + lq.length),
          style: TextStyle(
              backgroundColor: kPaletteAccent.withValues(alpha: 0.16),
              color: Colors.black87)),
      TextSpan(text: preview.substring(idx + lq.length)),
    ]),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

/// 빈 검색 화면의 날짜 퀵 칩 — 날짜로도 찾을 수 있다는 걸 노출(발견성).
Widget dateChips(void Function(String) onPick) {
  const items = ['오늘', '어제', '이번 주', '지난 주', '이번 달'];
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
    child: Row(
      children: [
        const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.black26),
        const SizedBox(width: 9),
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(t),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x07000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x0F000000)),
                ),
                child: Text(t,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ),
          ),
      ],
    ),
  );
}
