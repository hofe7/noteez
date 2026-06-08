import 'date_query.dart';
import 'models/sticky.dart';

/// 검색 결과: 키워드/날짜로 맞은 exact + 의미상 가까운 related(AI 관련).
typedef SearchResult = ({List<Sticky> exact, List<Sticky> related});

/// 의미 점수 제공자: 쿼리 → {stickyId: cosine}. (ConnectionEngine.rankByQuery 주입)
typedef SemanticScores = Future<Map<String, double>> Function(String query);

/// 검색 로직(순수). UI/IPC/모델 로딩과 분리 — stickies + 의미점수 콜백만 받는다.
///  - exact: 키워드가 실제로 들어있는 메모(또는 날짜/빈쿼리 결과).
///  - related: 키워드는 없지만 의미상 가까운 메모. 노이즈 방지로 높은 바 + 소수만.
Future<SearchResult> searchStickies(
  List<Sticky> stickies,
  String query,
  DateTime now,
  SemanticScores semanticScores,
) async {
  final q = query.trim();
  if (q.isEmpty) {
    final recent = [...stickies]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return (exact: recent, related: const <Sticky>[]);
  }

  // 날짜 질의면 작성·수정일로 필터(전부 정확 묶음).
  final range = parseDateQuery(q, now);
  if (range != null) {
    final hits = stickies
        .where((s) => range.contains(s.createdAt) || range.contains(s.updatedAt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (exact: hits, related: const <Sticky>[]);
  }

  // 키워드 일치는 띄어쓰기·대소문자 무시 ("구조개선"="구조 개선", "redis"="Redis").
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final nq = norm(q);
  bool kw(Sticky s) => s.blocks.any((b) => norm(b.text).contains(nq));

  final exact = stickies.where(kw).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final exactIds = {for (final s in exact) s.id};

  // 의미상 관련 — 키워드엔 없지만 임베딩 점수 높은 것 (음차 "레디스"→Redis 등).
  // 정확 일치가 있으면 엄격(보너스만), 없으면 관대(의미검색이 곧 답) → 빈 결과 방지.
  final sem = await semanticScores(q);
  final double relatedBar = exact.isEmpty ? 0.80 : 0.88;
  final int relatedMax = exact.isEmpty ? 6 : 4;
  final cands = stickies
      .where((s) => !exactIds.contains(s.id))
      .map((s) => MapEntry(s, sem[s.id] ?? 0.0))
      .where((e) => e.value >= relatedBar)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final related = <Sticky>[
    for (final e in cands.take(relatedMax)) e.key,
  ];
  return (exact: exact, related: related);
}
