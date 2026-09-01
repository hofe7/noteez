import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'models/model_catalog.dart';

typedef SearchHttpClientFactory = HttpClient Function();

class HuggingFaceSearchResult {
  const HuggingFaceSearchResult({required this.models, required this.checked});

  final List<EmbeddingModel> models;
  final int checked;

  Map<String, dynamic> toJson() => {
    'models': [for (final model in models) model.toJson()],
    'checked': checked,
    'rejected': checked - models.length,
  };
}

/// Hugging Face 검색 결과를 Noteez가 실행할 수 있는 좁은 ONNX 형식으로 바꾼다.
///
/// 모델 저장소의 코드는 내려받거나 실행하지 않는다. 고정 commit, LFS SHA-256,
/// 파일 크기, XLM-R tokenizer, multilingual-e5 계열을 모두 확인한 결과만 반환한다.
class HuggingFaceModelSearch {
  HuggingFaceModelSearch({
    SearchHttpClientFactory? httpClientFactory,
    Uri? origin,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _origin = origin ?? Uri.parse('https://huggingface.co');

  final SearchHttpClientFactory _httpClientFactory;
  final Uri _origin;

  static const _allowedLicenses = {
    'mit',
    'apache-2.0',
    'bsd-2-clause',
    'bsd-3-clause',
    'cc-by-4.0',
  };

  Future<HuggingFaceSearchResult> search(String query) async {
    final text = query.trim().isEmpty ? 'multilingual-e5' : query.trim();
    final client = _httpClientFactory();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final uri = _uri('/api/models', {
        'search': text,
        'pipeline_tag': 'sentence-similarity',
        'limit': '12',
        'full': 'true',
      });
      final raw = await _getJson(client, uri);
      if (raw is! List) throw const FormatException('검색 응답 형식이 다릅니다.');
      final summaries = raw.whereType<Map<String, dynamic>>().where(
        _looksCompatible,
      );
      final checked = summaries.length > 8 ? 8 : summaries.length;
      final converted = await Future.wait([
        for (final summary in summaries.take(8))
          _inspect(client, summary).catchError((_) => null),
      ]);
      final models = converted.whereType<EmbeddingModel>().toList()
        ..sort((a, b) => a.downloadBytes.compareTo(b.downloadBytes));
      return HuggingFaceSearchResult(models: models, checked: checked);
    } finally {
      client.close(force: true);
    }
  }

  bool _looksCompatible(Map<String, dynamic> summary) {
    final id = summary['id'] as String? ?? '';
    final tags = (summary['tags'] as List?)?.whereType<String>().toList() ?? [];
    final lowered = tags.map((tag) => tag.toLowerCase()).toList();
    final e5Family =
        id.toLowerCase().contains('multilingual-e5') ||
        lowered.any(
          (tag) => tag.startsWith('base_model:intfloat/multilingual-e5'),
        );
    return e5Family &&
        lowered.contains('onnx') &&
        lowered.contains('sentence-transformers') &&
        !lowered.contains('custom_code') &&
        !lowered.contains('gguf');
  }

  Future<EmbeddingModel?> _inspect(
    HttpClient client,
    Map<String, dynamic> summary,
  ) async {
    final repository = summary['id'] as String?;
    if (repository == null ||
        !RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository)) {
      return null;
    }
    final detailRaw = await _getJson(
      client,
      _uri('/api/models/$repository', {'blobs': 'true'}),
    );
    if (detailRaw is! Map<String, dynamic>) return null;
    final revision = detailRaw['sha'] as String?;
    if (revision == null || !RegExp(r'^[a-f0-9]{40,64}$').hasMatch(revision)) {
      return null;
    }
    final tags =
        (detailRaw['tags'] as List?)?.whereType<String>().toList() ?? [];
    if (tags.any((tag) => tag.toLowerCase() == 'custom_code')) return null;
    final license = _license(detailRaw, tags);
    if (!_allowedLicenses.contains(license)) return null;

    final siblings =
        (detailRaw['siblings'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];
    final modelFile = _selectModelFile(siblings);
    final tokenizerFile = _selectTokenizer(siblings);
    if (modelFile == null || tokenizerFile == null) return null;

    final configPath = modelFile.path.contains('/')
        ? '${modelFile.path.substring(0, modelFile.path.lastIndexOf('/'))}/config.json'
        : 'config.json';
    Map<String, dynamic>? modelConfig;
    if (siblings.any((file) => file['rfilename'] == configPath)) {
      final raw = await _getJson(
        client,
        _uri('/$repository/resolve/$revision/$configPath'),
      );
      if (raw is Map<String, dynamic>) modelConfig = raw;
    }
    modelConfig ??= detailRaw['config'] as Map<String, dynamic>?;
    final dimensions = (modelConfig?['hidden_size'] as num?)?.toInt();
    final tokenizerClass = modelConfig?['tokenizer_class'] as String?;
    final modelType = modelConfig?['model_type'] as String?;
    final architectures =
        (modelConfig?['architectures'] as List?)?.whereType<String>().toSet() ??
        const <String>{};
    if (dimensions == null || dimensions < 1 || dimensions > 1024) return null;
    final xlmTokenizer =
        tokenizerClass == 'XLMRobertaTokenizer' ||
        tokenizerClass == 'XLMRobertaTokenizerFast';
    final xlmArchitecture =
        modelType == 'xlm-roberta' && architectures.contains('XLMRobertaModel');
    if (!xlmTokenizer && !xlmArchitecture) {
      return null;
    }

    final total = modelFile.bytes + tokenizerFile.bytes;
    if (total > 1536 * 1024 * 1024) return null;
    final id = sha256
        .convert(utf8.encode('$repository@$revision'))
        .toString()
        .substring(0, 16);
    return EmbeddingModel(
      id: 'hf-$id',
      name: repository.split('/').last,
      description: '호환성 검사를 통과한 Hugging Face 커뮤니티 모델',
      badge: '커뮤니티',
      repository: repository,
      revision: revision,
      dimensions: dimensions,
      license: license,
      artifacts: [
        ModelArtifact(
          remotePath: modelFile.path,
          localName: 'model.onnx',
          bytes: modelFile.bytes,
          sha256: modelFile.sha256,
        ),
        ModelArtifact(
          remotePath: tokenizerFile.path,
          localName: 'tokenizer.json',
          bytes: tokenizerFile.bytes,
          sha256: tokenizerFile.sha256,
        ),
      ],
    );
  }

  String _license(Map<String, dynamic> detail, List<String> tags) {
    final card = detail['cardData'];
    final fromCard = card is Map<String, dynamic>
        ? card['license'] as String?
        : null;
    if (fromCard != null) return fromCard.toLowerCase();
    for (final tag in tags) {
      if (tag.startsWith('license:')) return tag.substring(8).toLowerCase();
    }
    return 'unknown';
  }

  _RemoteFile? _selectModelFile(List<Map<String, dynamic>> siblings) {
    const priorities = [
      'model_qint8_arm64.onnx',
      'model_qint8.onnx',
      'model_qint8_avx512_vnni.onnx',
      'model_int8.onnx',
      'model_quantized.onnx',
    ];
    final files = siblings
        .map(_remoteFile)
        .whereType<_RemoteFile>()
        .where(
          (file) => file.path.endsWith('.onnx') && file.bytes >= 1024 * 1024,
        );
    for (final name in priorities) {
      for (final file in files) {
        if (file.path.split('/').last == name) return file;
      }
    }
    return null;
  }

  _RemoteFile? _selectTokenizer(List<Map<String, dynamic>> siblings) {
    final files = siblings.map(_remoteFile).whereType<_RemoteFile>();
    for (final preferred in const ['onnx/tokenizer.json', 'tokenizer.json']) {
      for (final file in files) {
        if (file.path == preferred) return file;
      }
    }
    return null;
  }

  _RemoteFile? _remoteFile(Map<String, dynamic> value) {
    final path = value['rfilename'] as String?;
    final lfs = value['lfs'];
    if (path == null ||
        path.startsWith('/') ||
        path.split('/').contains('..')) {
      return null;
    }
    if (lfs is! Map<String, dynamic>) return null;
    final bytes =
        (value['size'] as num?)?.toInt() ?? (lfs['size'] as num?)?.toInt();
    final hash = lfs['sha256'] as String?;
    if (bytes == null ||
        bytes <= 0 ||
        hash == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    return _RemoteFile(path, bytes, hash);
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      _origin.replace(path: path, queryParameters: query);

  Future<Object?> _getJson(HttpClient client, Uri uri) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.userAgentHeader, 'Noteez/1.0 model-search');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Hugging Face가 HTTP ${response.statusCode}을 반환했습니다.',
        uri: uri,
      );
    }
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 30));
    return jsonDecode(body);
  }
}

class _RemoteFile {
  const _RemoteFile(this.path, this.bytes, this.sha256);

  final String path;
  final int bytes;
  final String sha256;
}
