import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/models/sticky.dart';
import 'package:noteez/sticky_search.dart';

Sticky _s(String id, String text, {int created = 0, int updated = 0}) => Sticky(
      id: id,
      blocks: [TextBlock(id: '$id-b', text: text)],
      colorIndex: 0,
      x: 0,
      y: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated),
    );

Future<Map<String, double>> _noSem(String q) async => const {};

void main() {
  final now = DateTime(2026, 6, 8);

  test('빈 쿼리 → 최근 수정순 전체, related 없음', () async {
    final list = [
      _s('a', '오래', updated: 100),
      _s('b', '최근', updated: 900),
    ];
    final r = await searchStickies(list, '   ', now, _noSem);
    expect(r.exact.map((s) => s.id), ['b', 'a']);
    expect(r.related, isEmpty);
  });

  test('키워드 일치는 띄어쓰기·대소문자 무시', () async {
    final list = [
      _s('a', 'Redis 캐시 구조 개선'),
      _s('b', '점심 메뉴'),
    ];
    final r = await searchStickies(list, '구조개선', now, _noSem);
    expect(r.exact.map((s) => s.id), ['a']);
    final r2 = await searchStickies(list, 'redis', now, _noSem);
    expect(r2.exact.map((s) => s.id), ['a']);
  });

  test('의미 관련: 키워드 없을 때 바 0.80, exact 있으면 0.88', () async {
    final list = [
      _s('hit', 'Redis 캐시'),
      _s('near', '레디스 메모리 저장소'),
      _s('far', '저녁 약속'),
    ];
    // near=0.84 (>=0.80, <0.88), far=0.5
    Future<Map<String, double>> sem(String q) async =>
        {'near': 0.84, 'far': 0.5};

    // 키워드 'redis' → hit 은 exact, near 는 0.84 → exact 있으니 바 0.88 → 탈락.
    final withExact = await searchStickies(list, 'redis', now, sem);
    expect(withExact.exact.map((s) => s.id), ['hit']);
    expect(withExact.related, isEmpty, reason: 'exact 있으면 바 0.88, near 0.84 탈락');

    // 어느 메모 텍스트에도 없는 토큰 → 키워드 매치 0(exact 비어 바 0.80) → near 의미통과.
    final noExact = await searchStickies(list, 'xyzzy', now, sem);
    expect(noExact.exact, isEmpty);
    expect(noExact.related.map((s) => s.id), ['near'],
        reason: 'exact 없으면 바 0.80, near 0.84 통과');
  });

  test('날짜 질의는 작성/수정일로 필터(related 없음)', () async {
    final list = [
      _s('today', '오늘 메모',
          created: DateTime(2026, 6, 8, 10).millisecondsSinceEpoch),
      _s('old', '예전 메모',
          created: DateTime(2026, 1, 1).millisecondsSinceEpoch),
    ];
    final r = await searchStickies(list, '오늘', now, _noSem);
    expect(r.exact.map((s) => s.id), ['today']);
    expect(r.related, isEmpty);
  });
}
