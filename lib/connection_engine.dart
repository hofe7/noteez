import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'embed/embedding_worker.dart';
import 'embed/document_embedding.dart';
import 'automatic_clusters.dart';
import 'hybrid_relevance.dart';
import 'group_suggestions.dart';
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
  ConnectionEngine({TextEmbedder Function(InstalledModel)? embedderFactory})
    : _embedderFactory =
          embedderFactory ??
          ((model) => EmbeddingWorker(model.modelPath, model.tokenizerPath));

  final TextEmbedder Function(InstalledModel) _embedderFactory;
  TextEmbedder? _embedder;
  InstalledModel? _model;
  bool _ready = false;
  bool _closed = false;
  int _generation = 0;
  final Map<String, int> _versions = {};
  Future<void> _tail = Future.value();

  final Map<String, ({String signature, PreparedMemo memo})> _features = {};
  final Map<String, int> _vectorVersions = {};
  final Map<(String, String, String, String, int, int), HybridRelevanceResult>
  _pairCache = {};
  static const _maximumCachedPairs = 50000;

  void _prepare(List<Sticky> all) {
    final live = <String>{};
    for (final note in all) {
      live.add(note.id);
      final signature =
          '${documentHash(note)}:${note.contentUpdatedAt.millisecondsSinceEpoch}';
      if (_features[note.id]?.signature != signature) {
        _features[note.id] = (
          signature: signature,
          memo: HybridRelevance.prepare(note),
        );
      }
    }
    _features.removeWhere((id, _) => !live.contains(id));
  }

  HybridRelevanceResult _relevance(String a, String b) {
    if (a.compareTo(b) > 0) {
      (a, b) = (b, a);
    }
    final fa = _features[a]!;
    final fb = _features[b]!;
    final key = (
      a,
      b,
      fa.signature,
      fb.signature,
      _vectorVersions[a] ?? 0,
      _vectorVersions[b] ?? 0,
    );
    final cached = _pairCache.remove(key);
    if (cached != null) {
      _pairCache[key] = cached;
      return cached;
    }
    final av = _vectors[a];
    final bv = _vectors[b];
    final result = HybridRelevance.evaluatePrepared(
      fa.memo,
      fb.memo,
      semanticScore: av != null && bv != null ? _cos(av, bv) : null,
    );
    if (_pairCache.length >= _maximumCachedPairs) {
      _pairCache.remove(_pairCache.keys.first);
    }
    _pairCache[key] = result;
    return result;
  }

  void _vectorChanged(String id) {
    _vectorVersions[id] = (_vectorVersions[id] ?? 0) + 1;
  }

  final Map<String, List<double>> _vectors = {};
  final Map<String, String> _hashes = {};
  final Map<String, DocumentEmbedding> _documents = {};

  /// 임베딩 계산되면 영속화 콜백 (id, hash, vecJson). MainController 가 DB에 저장.
  Future<void> Function(String id, String hash, String vec)? onPersist;

  bool get ready => _ready;
  String? get modelId => _model?.profile.id;

  /// 설치/선택된 모델을 교체한다. 서로 다른 모델의 벡터는 비교할 수 없으므로
  /// 메모리 캐시도 함께 비우고 다음 warmup에서 다시 만든다.
  void selectModel(InstalledModel? model) {
    if (_model?.profile.id == model?.profile.id &&
        _model?.modelPath == model?.modelPath) {
      return;
    }
    final previous = _embedder;
    if (previous != null) unawaited(previous.close());
    _embedder = null;
    _ready = false;
    _model = model;
    clearEmbeddings();
  }

  void clearEmbeddings() {
    _generation++;
    _pairCache.clear();
    _vectorVersions.clear();
    _vectors.clear();
    _documents.clear();
    _hashes.clear();
  }

  /// DB에 저장된 임베딩을 메모리에 로드 (모델 불필요).
  void seed(String id, String hash, List<double> vec) {
    _vectorChanged(id);
    _vectors[id] = vec;
    _hashes[id] = hash;
  }

  /// Legacy vectors are rebuilt once. Stale document chunks remain reusable,
  /// but are never exposed to search or recommendations before reindexing.
  void seedStored(Sticky note, String hash, String payload) {
    DocumentEmbedding? document;
    try {
      document = DocumentEmbedding.parse(jsonDecode(payload));
    } catch (_) {
      return;
    }
    if (document == null) return;
    _documents[note.id] = document;
    if (hash == embeddingHash(note)) seed(note.id, hash, document.vector);
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

  /// Cache identity includes paragraph boundaries; dismissal identity stays stable.
  String embeddingHash(Sticky sticky) =>
      _hashOf(jsonEncode(sticky.blocks.map((b) => b.text).toList()));

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

  TextEmbedder? _ensureModel() {
    if (_closed || _model == null) return null;
    return _embedder ??= _embedderFactory(_model!);
  }

  /// Serialize inference and skip superseded queued edits. A generation and
  /// per-note revision prevent stale results after edits, deletion or switching.
  Future<void> index(Sticky s) {
    if (_closed) return Future.value();
    final generation = _generation;
    final version = (_versions[s.id] ?? 0) + 1;
    _versions[s.id] = version;
    final text = _text(s);
    final hash = embeddingHash(s);
    // Never recommend from a vector that describes an older document.
    if (_hashes[s.id] != hash) {
      _vectorChanged(s.id);
      _vectors.remove(s.id);
      _hashes.remove(s.id);
    }
    bool current() =>
        !_closed && generation == _generation && _versions[s.id] == version;
    final operation = _tail.then((_) async {
      if (!current()) return;
      if (text.isEmpty) return;
      if (_hashes[s.id] == hash && _vectors.containsKey(s.id)) return;
      final worker = _ensureModel();
      if (worker == null) return;
      try {
        final document = worker is DocumentEmbedder
            ? await worker.embedDocument(
                s.blocks.map((b) => b.text).toList(),
                _documents[s.id]?.chunks ?? const {},
              )
            : null;
        final vector = document?.vector ?? await worker.embed('passage: $text');
        if (!current()) return;
        _vectorChanged(s.id);
        _vectors[s.id] = vector;
        if (document != null) _documents[s.id] = document;
        _hashes[s.id] = hash;
        _ready = true;
        await onPersist?.call(
          s.id,
          hash,
          jsonEncode(document?.toJson() ?? vector),
        );
      } catch (_) {
        if (current()) rethrow;
      }
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> close() async {
    _closed = true;
    _generation++;
    await _tail;
    await _embedder?.close();
    _embedder = null;
  }

  /// 시작 시 백그라운드: 저장 안 됐거나 바뀐 메모만 임베딩(모델은 그때만 로드).
  Future<void> warmup(
    List<Sticky> stickies, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final activeModel = modelId;
    final versionsAtStart = Map<String, int>.of(_versions);
    var completed = 0;
    for (final s in stickies) {
      if (modelId != activeModel) return;
      if ((_versions[s.id] ?? 0) == (versionsAtStart[s.id] ?? 0)) {
        await index(s);
      }
      if (modelId != activeModel) return;
      completed++;
      onProgress?.call(completed, stickies.length);
    }
  }

  void remove(String id) {
    _vectorChanged(id);
    _features.remove(id);
    _documents.remove(id);
    _versions[id] = (_versions[id] ?? 0) + 1;
    _vectors.remove(id);
    _hashes.remove(id);
  }

  /// 의미 검색: 쿼리(e5 'query:' 프리픽스)와 모든 메모의 코사인, 내림차순.
  /// 첫 호출 시 모델 lazy 로드.
  Future<List<MapEntry<String, double>>> rankByQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final generation = _generation;
    final worker = _ensureModel();
    if (worker == null) return const [];
    List<double> qv;
    try {
      qv = await worker.embed('query: $q');
    } catch (_) {
      if (generation != _generation) return const [];
      rethrow;
    }
    if (generation != _generation || _closed) return const [];
    _ready = true;
    final out = <MapEntry<String, double>>[
      for (final e in _vectors.entries)
        MapEntry(
          e.key,
          _documents[e.key]?.chunks.values
                  .map((v) => _cos(qv, v))
                  .reduce(max) ??
              _cos(qv, e.value),
        ),
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
    _prepare(all);
    return _connectionForPrepared(
      id,
      all,
      exclude: exclude,
      isDismissed: isDismissed,
    );
  }

  Connection? _connectionForPrepared(
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
      final result = _relevance(id, candidate.id);
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

  /// Collect the same recommendations shown on individual notes, once per pair.
  List<Map<String, dynamic>> referenceSuggestions(
    List<Sticky> all, {
    required bool Function(String, String) isLinked,
    bool Function(String, String)? isDismissed,
    Map<String, String> memberships = const {},
  }) {
    _prepare(all);
    final pairs = <String, Map<String, dynamic>>{};
    for (final note in all) {
      final group = memberships[note.id];
      final suggestion = _connectionForPrepared(
        note.id,
        all,
        exclude: {
          for (final other in all)
            if (isLinked(note.id, other.id) ||
                (group != null && memberships[other.id] == group))
              other.id,
        },
        isDismissed: isDismissed,
      );
      if (suggestion == null) continue;
      final ids = [note.id, suggestion.id]..sort();
      final key = jsonEncode(ids);
      if ((pairs[key]?['score'] as double? ?? -1) >= suggestion.score) continue;
      pairs[key] = {
        'a': ids[0],
        'b': ids[1],
        'score': suggestion.score,
        'reasons': suggestion.reasons,
      };
    }
    final result = pairs.values.toList()
      ..sort((a, b) {
        final score = (b['score'] as double).compareTo(a['score'] as double);
        return score != 0
            ? score
            : jsonEncode([
                a['a'],
                a['b'],
              ]).compareTo(jsonEncode([b['a'], b['b']]));
      });
    return result;
  }

  /// 기존 묶음에 속하지 않은 메모를 작은 하이브리드 묶음으로 제안한다.
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
    _prepare(all);
    HybridRelevanceResult relevance(String a, String b) => _relevance(a, b);

    final clusters = AutomaticClusterEngine.build(
      ids,
      relevance,
      modelId: modelId,
      isDismissed: isDismissed,
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

  List<GroupSuggestion> groupSuggestions(
    List<Sticky> all,
    Map<String, List<String>> groups, {
    bool Function(String, String)? isDismissed,
    bool Function(String, String)? isPairDismissed,
  }) {
    final byId = {for (final note in all) note.id: note};
    _prepare(all);
    return GroupSuggestionEngine.build(
      noteIds: all
          .where((note) => _text(note).length >= 6)
          .map((note) => note.id),
      groups: {
        for (final group in groups.entries)
          group.key: group.value.where(byId.containsKey).toList(),
      },
      isDismissed: isDismissed,
      isPairDismissed: isPairDismissed,
      relevance: _relevance,
    );
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
