import 'package:flutter/widgets.dart';

import 'models/sticky.dart';

abstract final class StickyWindowSizing {
  static const double headerHeight = 30;
  static const double maximumExpandedHeight = 560;

  static Size initialSize(Sticky sticky) =>
      Size(sticky.width, sticky.collapsed ? headerHeight : sticky.height);

  static double automaticExpandedHeight({
    required double bodyHeight,
    required double footerHeight,
  }) => (headerHeight + bodyHeight + footerHeight).clamp(
    kDefaultStickyHeight,
    maximumExpandedHeight,
  );

  static bool hasSavedManualSize(Sticky sticky) =>
      (sticky.width - kDefaultStickyWidth).abs() > 0.5 ||
      (sticky.height - kDefaultStickyHeight).abs() > 0.5;
}
