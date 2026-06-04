import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'embed/onnx_embedder.dart';
import 'embed/unigram_tokenizer.dart';
import 'models/sticky.dart';

class Connection {
  final String id;
  final String preview; // 첫 줄
  final String full; // 전체 내용(연결 전 판단용)
  final double score;
  const Connection(this.id, this.preview, this.full, this.score);

  Map<String, dynamic> toJson() =>
      {'id': id, 'preview': preview, 'full': full, 'score': score};
}

/// 온디바이스 임베딩 기반 "관련 메모" 엔진. 메인 프로세스가 소유.
/// - 벡터는 DB에 영속화(매 실행 재계산 안 함). 텍스트 hash 같으면 재사용.
/// - 모델(118MB)은 lazy 로드: 바뀐 메모를 임베딩하거나 검색할 때만.
class ConnectionEngine {
  OnnxEmbedder? _embedder;
  UnigramTokenizer? _tok;
  bool _triedModel = false;

  final Map<String, List<double>> _vectors = {};
  final Map<String, String> _hashes = {};

  /// 임베딩 계산되면 영속화 콜백 (id, hash, vecJson). MainController 가 DB에 저장.
  void Function(String id, String hash, String vec)? onPersist;

  bool get ready => _embedder != null;

  // 게이팅 (e5 점수가 좁게 뭉쳐서 절대 임계값 대신 상대 마진 병행). 실사용으로 튜닝.
  static const double _floor = 0.84;
  static const double _margin = 0.012;
  static const double _strong = 0.90;

  /// DB에 저장된 임베딩을 메모리에 로드 (모델 불필요).
  void seed(String id, String hash, List<double> vec) {
    _vectors[id] = vec;
    _hashes[id] = hash;
  }

  String _text(Sticky s) => s.blocks.map((b) => b.text).join(' ').trim();
  String _hashOf(String text) => text.hashCode.toString();

  Future<bool> _ensureModel() async {
    if (_embedder != null) return true;
    if (_triedModel) return false;
    _triedModel = true;
    try {
      final dir = '${Platform.environment['HOME']}/Documents';
      if (!File('$dir/e5_int8.onnx').existsSync()) return false;
      _embedder = OnnxEmbedder()..init('$dir/e5_int8.onnx');
      _tok = UnigramTokenizer()..load('$dir/e5_tokenizer.json');
      return true;
    } catch (_) {
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
    onPersist?.call(s.id, h, jsonEncode(vec));
  }

  /// 시작 시 백그라운드: 저장 안 됐거나 바뀐 메모만 임베딩(모델은 그때만 로드).
  Future<void> warmup(List<Sticky> stickies) async {
    for (final s in stickies) {
      await index(s);
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

  /// id 메모의 최고 관련 메모 1개 (게이팅 통과 시). 저장된 벡터만 사용(모델 불필요).
  /// exclude: 이미 승인-연결된 메모(중복 제안 방지).
  Connection? connectionFor(String id, List<Sticky> all,
      {Set<String> exclude = const {}}) {
    final v = _vectors[id];
    if (v == null) return null;

    String? bestId;
    var best = -2.0;
    var second = -2.0;
    for (final e in _vectors.entries) {
      if (e.key == id || exclude.contains(e.key)) continue;
      final c = _cos(v, e.value);
      if (c > best) {
        second = best;
        best = c;
        bestId = e.key;
      } else if (c > second) {
        second = c;
      }
    }
    if (bestId == null) return null;

    final pass = best >= _floor && (best - second >= _margin || best >= _strong);
    if (!pass) return null;

    for (final s in all) {
      if (s.id == bestId) {
        final full = s.blocks
            .map((b) => b.text.trim())
            .where((t) => t.isNotEmpty)
            .join('\n');
        return Connection(bestId, s.preview, full, best);
      }
    }
    return null;
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
