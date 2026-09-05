import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/group_suggestions.dart';
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  HybridRelevanceResult score(double value) => HybridRelevanceResult(
    score: value,
    reasons: const ['공통 주제'],
    sharedKeywords: const [],
    semanticScore: null,
    lexicalScore: value,
  );

  test('suggests only unassigned notes with enough supporting members', () {
    final result = GroupSuggestionEngine.build(
      noteIds: ['a', 'b', 'new'],
      groups: {
        'launch': ['a', 'b'],
      },
      relevance: (_, _) => score(0.85),
    );
    expect(result.single.noteId, 'new');
    expect(result.single.groupId, 'launch');
  });

  test('an ambiguous match between two groups is not suggested', () {
    expect(
      GroupSuggestionEngine.build(
        noteIds: ['new'],
        groups: {
          'a': ['a1'],
          'b': ['b1'],
        },
        relevance: (_, member) => score(member == 'a1' ? 0.85 : 0.82),
      ),
      isEmpty,
    );
  });

  test('one strong match does not outweigh unrelated group members', () {
    expect(
      GroupSuggestionEngine.build(
        noteIds: ['new'],
        groups: {
          'a': ['a1', 'a2', 'a3'],
        },
        relevance: (_, member) => score(member == 'a1' ? 0.99 : 0.2),
      ),
      isEmpty,
    );
  });

  test(
    'explicit rejection does not route a note into the second best group',
    () {
      expect(
        GroupSuggestionEngine.build(
          noteIds: ['new'],
          groups: {
            'a': ['a1'],
            'b': ['b1'],
          },
          relevance: (_, member) => score(member == 'a1' ? 0.95 : 0.75),
          isDismissed: (_, group) => group == 'a',
        ),
        isEmpty,
      );
    },
  );

  test('respects pair rejection and caps suggestions deterministically', () {
    final result = GroupSuggestionEngine.build(
      noteIds: ['e', 'd', 'c', 'b', 'a'],
      groups: {
        'group': ['member'],
      },
      relevance: (_, _) => score(0.85),
      isPairDismissed: (note, _) => note == 'a',
    );
    expect(result.map((s) => s.noteId), ['b', 'c', 'd']);
  });

  test('keyword-only engine adds new project notes to an existing group', () {
    Sticky note(String id, String text) => Sticky(
      id: id,
      blocks: [TextBlock(id: id, text: text)],
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    final result = ConnectionEngine().groupSuggestions(
      [
        note('a', '오로라 온보딩 업무 오류 수정'),
        note('b', '오로라 온보딩 업무 개선'),
        note('c', '주말 장보기 우유 계란'),
      ],
      {
        'project': ['a'],
      },
    );
    expect(result.single.noteId, 'b');
    expect(result.single.reasons, isNotEmpty);
  });
}
