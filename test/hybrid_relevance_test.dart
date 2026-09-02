import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/connection_engine.dart';
import 'package:noteez/hybrid_relevance.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  Sticky note(String id, String text, {int day = 1}) => Sticky(
    id: id,
    blocks: [TextBlock(id: '$id-block', text: text)],
    colorIndex: 0,
    x: 0,
    y: 0,
    createdAt: DateTime(2026, 9, day),
    updatedAt: DateTime(2026, 9, day),
  );

  test('shared project keywords can recommend without an AI model', () {
    final a = note('a', '오로라 온보딩 업무 오류 수정');
    final b = note('b', '오로라 온보딩 업무 개선');

    final result = HybridRelevance.evaluate(a, b);

    expect(result.score, greaterThan(HybridRelevance.suggestionThreshold));
    expect(result.sharedKeywords, containsAll(['오로라', '온보딩', '업무']));
    expect(result.reasons.join(' '), contains('키워드'));
  });

  test('same memo type and date alone are not enough to create noise', () {
    final a = note('a', '회의 결제 정책 논의');
    final b = note('b', '회의 채용 일정 논의');

    final result = HybridRelevance.evaluate(a, b);

    expect(result.score, lessThan(HybridRelevance.suggestionThreshold));
  });

  test('semantic similarity explains paraphrases without shared words', () {
    final a = note('a', '신규 고객의 첫 화면 이탈을 줄이자');
    final b = note('b', '가입 직후 사용자 경험을 단순하게 만들기');

    final result = HybridRelevance.evaluate(a, b, semanticScore: 0.91);

    expect(result.score, greaterThan(HybridRelevance.suggestionThreshold));
    expect(result.reasons, contains('표현은 달라도 의미가 가까워요'));
  });

  test('connection engine forms explained clusters without vectors', () {
    final notes = [
      note('a', '오로라 온보딩 업무 오류 수정'),
      note('b', '오로라 온보딩 업무 개선'),
      note('c', '주말 장보기 우유와 계란'),
    ];
    final engine = ConnectionEngine();

    final groups = engine.suggestedClusters(notes);

    expect(groups, hasLength(1));
    expect(groups.single.ids.toSet(), {'a', 'b'});
    expect(groups.single.reasons.join(' '), contains('키워드'));
    expect(groups.single.title, isNotEmpty);
    final suggestion = engine.connectionFor('a', notes);
    expect(suggestion?.id, 'b');
    expect(suggestion?.reasons.join(' '), contains('키워드'));
  });
}
