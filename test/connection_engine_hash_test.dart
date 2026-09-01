import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  Sticky sticky(String text) {
    final now = DateTime(2026, 8, 27);
    return Sticky(
      id: 'note',
      blocks: [TextBlock(id: 'block', text: text)],
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('contentHash is deterministic and changes with note content', () {
    final engine = ConnectionEngine();

    expect(engine.contentHash(sticky('메모 내용')), '13:d8191346');
    expect(
      engine.contentHash(sticky('메모 내용')),
      engine.contentHash(sticky('메모 내용')),
    );
    expect(
      engine.contentHash(sticky('메모 내용 수정')),
      isNot(engine.contentHash(sticky('메모 내용'))),
    );
  });
}
