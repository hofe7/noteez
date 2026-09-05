import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  test(
    'reference recommendations deduplicate directions and respect saved links, groups and dismissals',
    () async {
      final notes = [
        for (final id in ['a', 'b'])
          Sticky(
            id: id,
            blocks: [TextBlock(id: id, text: '검색 캐시 성능 개선')],
            colorIndex: 0,
            x: 0,
            y: 0,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
      ];
      final engine = ConnectionEngine();
      addTearDown(engine.close);
      for (final note in notes) {
        engine.seed(note.id, engine.embeddingHash(note), [1, 0]);
      }
      final pairs = engine.referenceSuggestions(
        notes,
        isLinked: (_, _) => false,
      );
      expect(pairs, hasLength(1));
      expect(pairs.single['a'], 'a');
      expect(pairs.single['b'], 'b');
      expect(pairs.single['reasons'], isNotEmpty);
      expect(
        engine.referenceSuggestions(notes, isLinked: (_, _) => true),
        isEmpty,
      );
      expect(
        engine.referenceSuggestions(
          notes,
          isLinked: (_, _) => false,
          isDismissed: (_, _) => true,
        ),
        isEmpty,
      );
      expect(
        engine.referenceSuggestions(
          notes,
          isLinked: (_, _) => false,
          memberships: {'a': 'g', 'b': 'g'},
        ),
        isEmpty,
      );
      expect(
        engine.referenceSuggestions(
          notes,
          isLinked: (_, _) => false,
          memberships: {'a': 'g', 'b': 'h'},
        ),
        hasLength(1),
      );
      expect(
        engine.referenceSuggestions([notes.first], isLinked: (_, _) => false),
        isEmpty,
      );
    },
  );
}
