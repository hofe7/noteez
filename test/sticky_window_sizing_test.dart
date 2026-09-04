import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/sticky_window_sizing.dart';

void main() {
  test('a short note keeps a comfortable minimum size', () {
    expect(
      StickyWindowSizing.automaticExpandedHeight(
        bodyHeight: 24,
        footerHeight: 0,
      ),
      kDefaultStickyHeight,
    );
  });

  test('content grows vertically until the maximum height', () {
    expect(
      StickyWindowSizing.automaticExpandedHeight(
        bodyHeight: 280,
        footerHeight: 20,
      ),
      330,
    );
    expect(
      StickyWindowSizing.automaticExpandedHeight(
        bodyHeight: 900,
        footerHeight: 100,
      ),
      StickyWindowSizing.maximumExpandedHeight,
    );
  });

  test('initial size restores a manual size and respects collapse', () {
    final expanded = makeSticky(x: 0, y: 0).copyWith(width: 430, height: 370);
    final collapsed = expanded.copyWith(collapsed: true);

    expect(StickyWindowSizing.initialSize(expanded).width, 430);
    expect(StickyWindowSizing.initialSize(expanded).height, 370);
    expect(StickyWindowSizing.initialSize(collapsed).width, 430);
    expect(
      StickyWindowSizing.initialSize(collapsed).height,
      StickyWindowSizing.headerHeight,
    );
    expect(StickyWindowSizing.hasSavedManualSize(expanded), isTrue);
    expect(
      StickyWindowSizing.hasSavedManualSize(makeSticky(x: 0, y: 0)),
      isFalse,
    );
  });
}
