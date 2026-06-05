import 'package:flutter/material.dart';

/// Noteez 공통 디자인 토큰 — 검색 팔레트(시그니처 톤)에서 추출.
/// 따뜻한 오프화이트 + 허니 앰버 + 가벼운 타이포 + Material 크롬 없음.
class AppColors {
  static const accent = Color(0xFFE8A33D); // 허니 앰버 (포스트잇 파스텔 한 식구)
  static const accentInk = Color(0xFF9A6E1E); // 앰버 칩 on 상태의 진한 텍스트
  static const surface = Color(0xFFFFFDF8); // 카드/입력 오프화이트
  static const bg = Color(0xFFFBF8F1); // 창 배경 (살짝 더 따뜻한 크림)
  static const paper = Color(0xFFFFEFAE); // 포스트잇 종이색
  static const inkOnPaper = Color(0xFF6E561B);

  // 잉크(텍스트) 단계 — black 알파로 통일.
  static const ink = Color(0xDE000000); // primary  (black87)
  static const ink2 = Color(0x8A000000); // secondary (black54)
  static const ink3 = Color(0x61000000); // tertiary  (black38)

  // 선/면.
  static const border = Color(0x0F000000);
  static const borderStrong = Color(0x14000000);
  static const hair = Color(0x0D000000); // divider
  static const fill = Color(0x07000000); // subtle chip bg
  static const fill2 = Color(0x0A000000);

  static Color accentTint([double a = 0.16]) => accent.withValues(alpha: a);
}

/// 공통 패널/카드 그림자 (검색 팔레트 값).
const kPanelShadow = <BoxShadow>[
  BoxShadow(color: Color(0x1A000000), blurRadius: 28, offset: Offset(0, 12)),
  BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2)),
];
const kCardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4)),
];

/// 일반 창(리포트·전체 보기)용 테마. Material 기본 크롬(보라 리플·M3 시드색)을
/// 끄고 허니 앰버 + 따뜻한 배경으로 통일.
ThemeData noteezTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.hair,
    splashFactory: NoSplash.splashFactory, // Material 리플 제거
    highlightColor: Colors.transparent,
    hoverColor: AppColors.fill,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x33E8A33D),
      selectionHandleColor: AppColors.accent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: const Color(0x22000000),
      surfaceTintColor: Colors.transparent,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 13, color: AppColors.ink),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xE63A3429),
        borderRadius: BorderRadius.circular(7),
      ),
      textStyle: const TextStyle(fontSize: 11.5, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );
}

/// 손으로 만든 세그먼트 컨트롤 (Material SegmentedButton 대체).
/// 알약형 트랙 + 선택 세그먼트는 앰버 틴트. 톤이 칩/팔레트와 한 식구.
class Segmented<T> extends StatelessWidget {
  final List<(T value, String label)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented(
      {super.key,
      required this.items,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: v == value ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: v == value
                      ? const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1))
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: v == value ? FontWeight.w700 : FontWeight.w500,
                    color: v == value ? AppColors.accentInk : AppColors.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
