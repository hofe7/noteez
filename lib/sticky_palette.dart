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
}
