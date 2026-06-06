import 'package:flutter/material.dart';

/// 가볍고 예쁜 파스텔 스티커 색. colorIndex가 이 팔레트를 가리킨다.
class StickyPalette {
  const StickyPalette._();

  static const List<Color> colors = <Color>[
    Color(0xFFFFF3B0), // yellow
    Color(0xFFFFD3DD), // pink
    Color(0xFFC9E7FF), // blue
    Color(0xFFD4F2D0), // green
    Color(0xFFE7DBFF), // purple
    Color(0xFFFFE0BE), // orange
  ];

  static Color of(int i) => colors[i % colors.length];

  /// 헤더는 본문보다 살짝 진하게.
  static Color header(int i) =>
      Color.alphaBlend(Colors.black.withValues(alpha: 0.07), of(i));

  /// 본문 위 강조(체크박스 등)용 — 같은 색조의 진한 잉크.
  static Color ink(int i) {
    final hsl = HSLColor.fromColor(of(i));
    return hsl
        .withSaturation((hsl.saturation + 0.35).clamp(0.0, 1.0))
        .withLightness(0.42)
        .toColor();
  }
}
