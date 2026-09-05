import 'dart:math';

import 'models/sticky.dart';

enum MemoKind { meeting, instruction, work, idea, personal }

class HybridRelevanceResult {
  const HybridRelevanceResult({
    required this.score,
    required this.reasons,
    required this.sharedKeywords,
    required this.semanticScore,
    required this.lexicalScore,
  });

  final double score;
  final List<String> reasons;
  final List<String> sharedKeywords;
  final double? semanticScore;
  final double lexicalScore;
}

/// Reusable note features; pair comparisons need not tokenize the same note again.
class PreparedMemo {
  const PreparedMemo(
    this.tokens,
    this.kinds,
    this.hasTodos,
    this.contentUpdatedAt,
  );
  final Set<String> tokens;
  final Set<MemoKind> kinds;
  final bool hasTodos;
  final DateTime contentUpdatedAt;
}

/// 임베딩 하나에만 의존하지 않고 사용자가 확인할 수 있는 로컬 신호를 합친다.
/// 네트워크나 생성형 모델 없이도 같은 프로젝트명·고유명사가 반복되는 메모는
/// 후보가 되며, 임베딩은 표현이 달라도 의미가 가까운 경우를 보완한다.
class HybridRelevance {
  const HybridRelevance._();

  static const double suggestionThreshold = 0.62;
  static const double strongThreshold = 0.78;

  static const Set<String> _stopWords = {
    '그리고',
    '하지만',
    '관련',
    '대한',
    '위한',
    '에서',
    '으로',
    '까지',
    '오늘',
    '내일',
    '이번',
    '다음',
    '확인',
    '진행',
    '내용',
    '정리',
    '필요',
    '메모',
    'the',
    'and',
    'for',
    'with',
    'this',
    'that',
  };

  static PreparedMemo prepare(Sticky note) {
    final text = _text(note);
    return PreparedMemo(
      _tokens(text),
      _kinds(text, note),
      note.blocks.any((block) => block is TodoBlock),
      note.contentUpdatedAt,
    );
  }

  static HybridRelevanceResult evaluate(
    Sticky a,
    Sticky b, {
    double? semanticScore,
    bool linked = false,
    bool sameGroup = false,
  }) => evaluatePrepared(
    prepare(a),
    prepare(b),
    semanticScore: semanticScore,
    linked: linked,
    sameGroup: sameGroup,
  );

  static HybridRelevanceResult evaluatePrepared(
    PreparedMemo a,
    PreparedMemo b, {
    double? semanticScore,
    bool linked = false,
    bool sameGroup = false,
  }) {
    final tokensA = a.tokens;
    final tokensB = b.tokens;
    final shared = tokensA.intersection(tokensB).toList()
      ..sort((x, y) {
        final byLength = y.length.compareTo(x.length);
        return byLength != 0 ? byLength : x.compareTo(y);
      });
    final lexical = _weightedOverlap(tokensA, tokensB, shared);
    final semantic = semanticScore == null
        ? null
        : ((semanticScore - 0.76) / 0.16).clamp(0.0, 1.0);
    final sharedKinds = a.kinds.intersection(b.kinds);
    final time = _timeProximity(a.contentUpdatedAt, b.contentUpdatedAt);
    final bothTodos = a.hasTodos && b.hasTodos;

    var score = semantic == null
        ? lexical * 0.82 +
              (sharedKinds.isEmpty ? 0 : 0.09) +
              time * 0.06 +
              (bothTodos ? 0.05 : 0)
        : semantic * 0.70 +
              lexical * 0.38 +
              (sharedKinds.isEmpty ? 0 : 0.06) +
              time * 0.04 +
              (bothTodos ? 0.03 : 0);
    if (linked) score += 0.18;
    if (sameGroup) score += 0.28;
    score = min(1.0, score);

    final reasons = <String>[];
    if (sameGroup) reasons.add('같은 수동 묶음에 있어요');
    if (linked) reasons.add('사용자가 직접 연결했어요');
    if (shared.isNotEmpty && lexical >= 0.16) {
      final shown = shared.take(2).map((word) => '‘$word’').join(', ');
      reasons.add('$shown 키워드가 겹쳐요');
    }
    if (semantic != null && semantic >= 0.52) {
      reasons.add('표현은 달라도 의미가 가까워요');
    }
    if (sharedKinds.isNotEmpty && reasons.length < 2) {
      reasons.add('${_kindLabel(sharedKinds.first)} 성격이 같아요');
    }
    if (time >= 0.65 && reasons.length < 2) {
      reasons.add(time == 1 ? '비슷한 시기에 작성했어요' : '같은 주에 다뤘어요');
    }
    if (bothTodos && reasons.length < 2) reasons.add('둘 다 할 일이 들어 있어요');

    return HybridRelevanceResult(
      score: score,
      reasons: reasons.take(2).toList(),
      sharedKeywords: shared,
      semanticScore: semanticScore,
      lexicalScore: lexical,
    );
  }

  static String _text(Sticky sticky) => sticky.blocks
      .map((block) => block.text.trim())
      .where((text) => text.isNotEmpty)
      .join(' ')
      .toLowerCase();

  static Set<String> _tokens(String text) => RegExp(r'[a-z0-9가-힣]{2,}')
      .allMatches(text)
      .map((match) => match.group(0)!)
      .where((token) {
        if (_stopWords.contains(token)) return false;
        if (RegExp(r'^\d+$').hasMatch(token)) return false;
        return true;
      })
      .toSet();

  static double _weightedOverlap(
    Set<String> a,
    Set<String> b,
    List<String> shared,
  ) {
    if (a.isEmpty || b.isEmpty || shared.isEmpty) return 0;
    double weight(String token) => min(2.5, 0.6 + token.length / 4);
    final sharedWeight = shared.fold<double>(
      0,
      (sum, token) => sum + weight(token),
    );
    final aWeight = a.fold<double>(0, (sum, token) => sum + weight(token));
    final bWeight = b.fold<double>(0, (sum, token) => sum + weight(token));
    return (sharedWeight / min(aWeight, bWeight)).clamp(0.0, 1.0);
  }

  static double _timeProximity(DateTime a, DateTime b) {
    final days = a.difference(b).inHours.abs() / 24;
    if (days <= 2) return 1;
    if (days <= 7) return 0.65;
    if (days <= 30) return 0.25;
    return 0;
  }

  static Set<MemoKind> _kinds(String text, Sticky sticky) {
    final kinds = <MemoKind>{};
    bool has(Iterable<String> words) => words.any(text.contains);
    if (has(['회의', '미팅', '논의', '회의록', '참석자', '안건'])) {
      kinds.add(MemoKind.meeting);
    }
    if (has(['지시', '요청', '전달', '담당', '마감', '해달라', '해주세요'])) {
      kinds.add(MemoKind.instruction);
    }
    if (has(['아이디어', '제안', '가설', '실험', '생각', '떠오름'])) {
      kinds.add(MemoKind.idea);
    }
    if (has(['개인', '장보기', '병원', '운동', '가족', '여행', '약속', '집'])) {
      kinds.add(MemoKind.personal);
    }
    if (has(['업무', '배포', '개발', '버그', '기획', '디자인', '고객', '프로젝트']) ||
        sticky.blocks.any((block) => block is TodoBlock)) {
      kinds.add(MemoKind.work);
    }
    return kinds;
  }

  static String _kindLabel(MemoKind kind) => switch (kind) {
    MemoKind.meeting => '회의 메모',
    MemoKind.instruction => '지시·요청',
    MemoKind.work => '업무 메모',
    MemoKind.idea => '아이디어',
    MemoKind.personal => '개인 메모',
  };
}
