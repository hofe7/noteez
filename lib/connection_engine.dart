import 'dart:convert';
import 'dart:math';

import 'embed/onnx_embedder.dart';
import 'embed/unigram_tokenizer.dart';
import 'hybrid_relevance.dart';
import 'model_manager.dart';
import 'models/sticky.dart';
import 'suggested_clusters.dart';

class Connection {
  final String id;
  final String preview; // 첫 줄
  final String full; // 전체 내용(연결 전 판단용)
  final double score;
  final List<String> reasons;
  const Connection(
    this.id,
    this.preview,
    this.full,
    this.score, {
    this.reasons = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'preview': preview,
    'full': full,
    'score': score,
    'reasons': reasons,
  };
}

/// 키워드·시점·메모 성격과 온디바이스 임베딩을 합친 "관련 메모" 엔진.
/// - 벡터는 DB에 영속화(매 실행 재계산 안 함). 텍스트 hash 같으면 재사용.
/// - 선택한 모델은 lazy 로드: 바뀐 메모를 임베딩하거나 검색할 때만.
class ConnectionEngine {
  OnnxEmbedder? _embedder;
  UnigramTokenizer? _tok;
  InstalledModel? _model;
  bool _triedModel = false;

  final Map<String, List<double>> _vectors = {};
  final Map<String, String> _hashes = {};

  /// 임베딩 계산되면 영속화 콜백 (id, hash, vecJson). MainController 가 DB에 저장.
  Future<void> Function(String id, String hash, String vec)? onPersist;

  bool get ready => _embedder != null;
  String? get modelId => _model?.profile.id;

  /// 설치/선택된 모델을 교체한다. 서로 다른 모델의 벡터는 비교할 수 없으므로
  /// 메모리 캐시도 함께 비우고 다음 warmup에서 다시 만든다.
  void selectModel(InstalledModel? model) {
    if (_model?.profile.id == model?.profile.id &&
        _model?.modelPath == model?.modelPath) {
      return;
    }
    _embedder?.dispose();
    _embedder = null;
    _tok = null;
    _model = model;
    _triedModel = false;
    clearEmbeddings();
  }

  void clearEmbeddings() {
    _vectors.clear();
    _hashes.clear();
  }

  /// DB에 저장된 임베딩을 메모리에 로드 (모델 불필요).
  void seed(String id, String hash, List<double> vec) {
    _vectors[id] = vec;
    _hashes[id] = hash;
  }

  String _text(Sticky s) => s.blocks.map((b) => b.text).join(' ').trim();
  String _hashOf(String text) {
    // Dart hashCode는 실행 간 안정성이 보장되지 않는다. DB 캐시와 추천 거절의
    // 콘텐츠 버전 키로 쓸 수 있도록 결정적인 FNV-1a 32bit를 사용한다.
    final bytes = utf8.encode(text);
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${bytes.length}:${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String contentHash(Sticky sticky) => _hashOf(_text(sticky));

  /// 사용자가 편집 가능한 문서 의미(텍스트/할 일 상태/이미지 이름)의 버전.
  /// 블록 UUID와 앱 내부 이미지 저장 경로는 제외해 Markdown 재파싱 결과와도 비교된다.
  String documentHash(Sticky sticky) => _hashOf(
    jsonEncode([
      for (final block in sticky.blocks)
        switch (block) {
          TextBlock text => {'type': 'text', 'text': text.text},
          TodoBlock todo => {
            'type': 'todo',
            'text': todo.text,
            'checked': todo.checked,
          },
          ImageBlock image => {
            'type': 'image',
            'name': image.path.replaceAll('\\', '/').split('/').last,
          },
        },
    ]),
  );

  Future<bool> _ensureModel() async {
    if (_embedder != null) return true;
    if (_triedModel) return false;
    _triedModel = true;
    try {
      final model = _model;
      if (model == null) return false;
      _embedder = OnnxEmbedder()..init(model.modelPath);
      _tok = UnigramTokenizer()..load(model.tokenizerPath);
      return true;
    } catch (_) {
      _embedder?.dispose();
      _embedder = null;
      _tok = null;
      return false;
    }
  }

  /// 메모 임베딩 갱신. 텍스트 안 바뀌었으면(hash 동일) 스킵.
  /// 바뀐 것만 모델 로드해서 재계산 + 영속화.
  Future<void> index(Sticky s) async {
    final txt = _text(s);
    if (txt.isEmpty) {
      _vectors.remove(s.id);
      _hashes.remove(s.id);
      return;
    }
    final h = _hashOf(txt);
    if (_hashes[s.id] == h && _vectors.containsKey(s.id)) return; // 이미 최신
    if (!await _ensureModel()) return;
    final ids = _tok!.encode('passage: $txt');
    final vec = _embedder!.embedFromIds(ids, List<int>.filled(ids.length, 1));
    _vectors[s.id] = vec;
    _hashes[s.id] = h;
    await onPersist?.call(s.id, h, jsonEncode(vec));
  }

  /// 시작 시 백그라운드: 저장 안 됐거나 바뀐 메모만 임베딩(모델은 그때만 로드).
  Future<void> warmup(
    List<Sticky> stickies, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final activeModel = modelId;
    var completed = 0;
    for (final s in stickies) {
      if (modelId != activeModel) return;
      await index(s);
      if (modelId != activeModel) return;
      completed++;
      onProgress?.call(completed, stickies.length);
    }
  }

  void remove(String id) {
    _vectors.remove(id);
    _hashes.remove(id);
  }

  /// 의미 검색: 쿼리(e5 'query:' 프리픽스)와 모든 메모의 코사인, 내림차순.
  /// 첫 호출 시 모델 lazy 로드.
  Future<List<MapEntry<String, double>>> rankByQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    if (!await _ensureModel()) return const [];
    final ids = _tok!.encode('query: $q');
    final qv = _embedder!.embedFromIds(ids, List<int>.filled(ids.length, 1));
    final out = <MapEntry<String, double>>[
      for (final e in _vectors.entries) MapEntry(e.key, _cos(qv, e.value)),
    ];
    out.sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// id 메모의 최고 관련 메모 1개. 임베딩이 있으면 의미 점수를 더하고, 없어도
  /// 공통 키워드·메모 성격·작성 시점으로 후보를 찾는다.
  Connection? connectionFor(
    String id,
    List<Sticky> all, {
    Set<String> exclude = const {},
    bool Function(String a, String b)? isDismissed,
  }) {
    Sticky? source;
    for (final sticky in all) {
      if (sticky.id == id) {
        source = sticky;
        break;
      }
    }
    if (source == null) return null;

    Sticky? bestSticky;
    HybridRelevanceResult? bestResult;
    var best = -2.0;
    var second = -2.0;
    for (final candidate in all) {
      if (candidate.id == id ||
          exclude.contains(candidate.id) ||
          (isDismissed?.call(id, candidate.id) ?? false)) {
        continue;
      }
      final sourceVector = _vectors[id];
      final candidateVector = _vectors[candidate.id];
      final result = HybridRelevance.evaluate(
        source,
        candidate,
        semanticScore: sourceVector != null && candidateVector != null
            ? _cos(sourceVector, candidateVector)
            : null,
      );
      if (result.score > best) {
        second = best;
        best = result.score;
        bestSticky = candidate;
        bestResult = result;
      } else if (result.score > second) {
        second = result.score;
      }
    }
    if (bestSticky == null || bestResult == null) return null;

    final pass =
        best >= HybridRelevance.suggestionThreshold &&
        (best - second >= 0.04 || best >= HybridRelevance.strongThreshold);
    if (!pass) return null;

    final full = bestSticky.blocks
        .map((b) => b.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
    return Connection(
      bestSticky.id,
      bestSticky.preview,
      full,
      best,
      reasons: bestResult.reasons,
    );
  }

  /// 확정 연결에 속하지 않은 메모를 작은 하이브리드 묶음으로 제안한다.
  /// 너무 짧은 메모는 일반 표현끼리 과하게 묶이는 것을 막기 위해 제외한다.
  List<SuggestedCluster> suggestedClusters(
    List<Sticky> all, {
    Set<String> exclude = const {},
    bool Function(String a, String b)? isDismissed,
  }) {
    final ids = <String>[
      for (final s in all)
        if (!exclude.contains(s.id) && _text(s).length >= 6) s.id,
    ];
    final byId = {for (final sticky in all) sticky.id: sticky};
    final pairResults = <String, HybridRelevanceResult>{};
    String key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
    HybridRelevanceResult relevance(String a, String b) {
      return pairResults.putIfAbsent(key(a, b), () {
        final av = _vectors[a];
        final bv = _vectors[b];
        return HybridRelevance.evaluate(
          byId[a]!,
          byId[b]!,
          semanticScore: av != null && bv != null ? _cos(av, bv) : null,
        );
      });
    }

    final clusters = SuggestedClusterEngine.build(
      ids,
      (a, b) =>
          (isDismissed?.call(a, b) ?? false) ? -2.0 : relevance(a, b).score,
      pairThreshold: HybridRelevance.suggestionThreshold,
      minimumCrossScore: 0.50,
    );
    return [
      for (final cluster in clusters)
        SuggestedCluster(
          cluster.ids,
          cluster.score,
          reasons: _clusterReasons(cluster.ids, relevance),
          title: _clusterTitle(cluster.ids, relevance),
        ),
    ];
  }

  List<String> _clusterReasons(
    List<String> ids,
    HybridRelevanceResult Function(String a, String b) relevance,
  ) {
    final counts = <String, int>{};
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        for (final reason in relevance(ids[i], ids[j]).reasons) {
          counts[reason] = (counts[reason] ?? 0) + 1;
        }
      }
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return ordered.take(2).map((entry) => entry.key).toList();
  }

  String? _clusterTitle(
    List<String> ids,
    HybridRelevanceResult Function(String a, String b) relevance,
  ) {
    final counts = <String, int>{};
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        for (final keyword in relevance(ids[i], ids[j]).sharedKeywords) {
          counts[keyword] = (counts[keyword] ?? 0) + 1;
        }
      }
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        final byLength = b.key.length.compareTo(a.key.length);
        return byLength != 0 ? byLength : a.key.compareTo(b.key);
      });
    if (ordered.isEmpty) return null;
    return ordered.take(2).map((entry) => entry.key).join(' · ');
  }

  static double _cos(List<double> a, List<double> b) {
    var d = 0.0;
    final n = min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      d += a[i] * b[i];
    }
    return d; // 둘 다 L2 정규화돼 있으므로 내적 = cosine
  }
}
