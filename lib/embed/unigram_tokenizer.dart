import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// XLM-RoBERTa(e5) Unigram(SentencePiece) 토크나이저의 순수 Dart 구현.
/// 파이프라인: Metaspace(▁) → Unigram Viterbi → [<s>] ids [</s>].
///
/// 주의: 원본 normalizer 의 Precompiled charsmap(NFKC류)은 생략.
/// 일반 한/영 입력엔 영향이 거의 없으며 fixture 로 정합성을 검증한다.
class UnigramTokenizer {
  static const int defaultMaxTokens = 512;
  static const int bos = 0; // <s>
  static const int eos = 2; // </s>
  static const int unk = 3; // <unk>
  static const String _meta = '▁'; // ▁

  late final List<double> _scores;
  late final Map<String, int> _pieceId;
  late final int _maxLen; // 최대 piece 길이(룬 기준)
  late final double _unkScore;

  void load(String tokenizerJsonPath) {
    final j =
        jsonDecode(File(tokenizerJsonPath).readAsStringSync())
            as Map<String, dynamic>;
    final vocab = (j['model'] as Map<String, dynamic>)['vocab'] as List;
    _scores = List<double>.filled(vocab.length, 0);
    _pieceId = HashMap<String, int>();
    var maxRunes = 1;
    var minScore = double.infinity;
    for (var i = 0; i < vocab.length; i++) {
      final entry = vocab[i] as List;
      final piece = entry[0] as String;
      final score = (entry[1] as num).toDouble();
      _scores[i] = score;
      _pieceId[piece] = i;
      final rl = piece.runes.length;
      if (rl > maxRunes) maxRunes = rl;
      if (score < minScore) minScore = score;
    }
    _maxLen = maxRunes;
    _unkScore = minScore - 10.0;
  }

  /// 텍스트 → 토큰 id 시퀀스 (<s> ... </s> 포함).
  ///
  /// multilingual-e5의 position embedding 한도에 맞춰 기본 512토큰으로
  /// 자른다. 마지막 토큰은 항상 </s>로 보존한다.
  List<int> encode(String text, {int maxTokens = defaultMaxTokens}) {
    if (maxTokens < 2) {
      throw ArgumentError.value(maxTokens, 'maxTokens', '2 이상이어야 합니다.');
    }
    final norm = _meta + text.replaceAll(' ', _meta);
    final cps = norm.runes.toList();
    final n = cps.length;

    final best = List<double>.filled(n + 1, double.negativeInfinity);
    final backStart = List<int>.filled(n + 1, -1);
    final backId = List<int>.filled(n + 1, -1);
    best[0] = 0;

    for (var i = 0; i < n; i++) {
      if (best[i] == double.negativeInfinity) continue;
      final maxL = (i + _maxLen <= n) ? _maxLen : n - i;
      for (var l = 1; l <= maxL; l++) {
        final sub = String.fromCharCodes(cps.sublist(i, i + l));
        final id = _pieceId[sub];
        if (id == null) continue;
        final sc = best[i] + _scores[id];
        if (sc > best[i + l]) {
          best[i + l] = sc;
          backStart[i + l] = i;
          backId[i + l] = id;
        }
      }
      // 단일 룬 unk 폴백 (어떤 piece 도 못 덮을 때만 이김)
      final scu = best[i] + _unkScore;
      if (scu > best[i + 1]) {
        best[i + 1] = scu;
        backStart[i + 1] = i;
        backId[i + 1] = unk;
      }
    }

    final mid = <int>[];
    var pos = n;
    while (pos > 0) {
      mid.add(backId[pos]);
      pos = backStart[pos];
    }
    final pieces = mid.reversed.toList(growable: false);
    if (pieces.length + 2 <= maxTokens) return [bos, ...pieces, eos];
    return [bos, ...pieces.take(maxTokens - 2), eos];
  }
}
