import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/model_catalog.dart';

enum ModelActivity { idle, downloading, verifying, failed }

class InstalledModel {
  const InstalledModel({
    required this.profile,
    required this.modelPath,
    required this.tokenizerPath,
  });

  final EmbeddingModel profile;
  final String modelPath;
  final String tokenizerPath;
}

typedef SupportDirectoryProvider = Future<Directory> Function();
typedef HttpClientFactory = HttpClient Function();
typedef DownloadUriResolver =
    Uri Function(EmbeddingModel model, ModelArtifact artifact);

/// 검증된 모델 카탈로그의 설치·선택·삭제를 소유한다.
///
/// 다운로드는 `.partial-*` 디렉터리에 받은 뒤 크기와 SHA-256이 모두 맞을 때만
/// 설치 경로로 rename한다. 중단되거나 손상된 파일이 실행되는 일이 없다.
class ModelManager extends ChangeNotifier {
  ModelManager({
    SupportDirectoryProvider? supportDirectory,
    HttpClientFactory? httpClientFactory,
    DownloadUriResolver? downloadUriResolver,
    List<EmbeddingModel> catalog = ModelCatalog.models,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _downloadUriResolver =
           downloadUriResolver ??
           ((model, artifact) => model.downloadUri(artifact)),
       _builtInCatalog = List.unmodifiable(catalog),
       _catalog = List.of(catalog);

  final SupportDirectoryProvider _supportDirectory;
  final HttpClientFactory _httpClientFactory;
  final DownloadUriResolver _downloadUriResolver;
  final List<EmbeddingModel> _builtInCatalog;
  final List<EmbeddingModel> _catalog;
  List<EmbeddingModel> get catalog => List.unmodifiable(_catalog);

  Directory? _root;
  final Set<String> _installed = {};
  String? _selectedId;
  String? _activeId;
  ModelActivity _activity = ModelActivity.idle;
  double _progress = 0;
  String? _error;
  HttpClient? _activeClient;
  bool _cancelRequested = false;
  int _lastProgressNotification = -1;

  String? get selectedId => _selectedId;
  String? get activeId => _activeId;
  ModelActivity get activity => _activity;
  double get progress => _progress;
  String? get error => _error;
  bool isInstalled(String id) => _installed.contains(id);
  bool get busy => _activeId != null;

  Future<void> initialize() async {
    final support = await _supportDirectory();
    _root = Directory('${support.path}/models');
    await _root!.create(recursive: true);
    await _loadCustomCatalog();
    await _loadState();
    _scanInstalled();
    if (!_installed.contains(_selectedId)) _selectedId = null;
    await _saveState();
    notifyListeners();
  }

  InstalledModel? get selectedModel {
    EmbeddingModel? profile;
    for (final candidate in catalog) {
      if (candidate.id == _selectedId) profile = candidate;
    }
    if (profile == null || !_installed.contains(profile.id) || _root == null) {
      return null;
    }
    final dir = Directory('${_root!.path}/${profile.id}');
    return InstalledModel(
      profile: profile,
      modelPath: '${dir.path}/model.onnx',
      tokenizerPath: '${dir.path}/tokenizer.json',
    );
  }

  Map<String, dynamic> toJson({int indexed = 0, int indexTotal = 0}) => {
    'selectedId': _selectedId,
    'activeId': _activeId,
    'activity': _activity.name,
    'progress': _progress,
    if (_error != null) 'error': _error,
    'indexed': indexed,
    'indexTotal': indexTotal,
    'models': [
      for (final model in catalog)
        {
          ...model.toJson(),
          'installed': _installed.contains(model.id),
          'selected': model.id == _selectedId,
        },
    ],
  };

  /// 호환성 검사를 통과한 Hugging Face 프로필을 로컬 카탈로그에 등록한다.
  /// 다운로드 URL, 파일명, 크기와 해시를 다시 검증해 IPC 입력을 신뢰하지 않는다.
  Future<void> registerCompatibleModel(EmbeddingModel profile) async {
    _validateCustomProfile(profile);
    final existing = _catalog.indexWhere((model) => model.id == profile.id);
    if (existing != -1) {
      final current = _catalog[existing];
      if (current.repository != profile.repository ||
          current.revision != profile.revision) {
        throw StateError('같은 ID로 다른 모델을 등록할 수 없습니다.');
      }
      _catalog[existing] = profile;
    } else {
      _catalog.add(profile);
    }
    await _saveCustomCatalog();
    _scanInstalled();
    notifyListeners();
  }

  Future<bool> downloadAndSelect(String id) async {
    final profile = _profile(id);
    if (busy) throw StateError('다른 모델을 다운로드하는 중입니다.');
    if (_installed.contains(id)) {
      await select(id);
      return true;
    }
    final root = _requireRoot();
    final staging = Directory(
      '${root.path}/.partial-${profile.id}-${DateTime.now().microsecondsSinceEpoch}',
    );
    await staging.create(recursive: true);
    _activeId = id;
    _activity = ModelActivity.downloading;
    _progress = 0;
    _error = null;
    _cancelRequested = false;
    _lastProgressNotification = -1;
    _activeClient = _httpClientFactory();
    _activeClient!.connectionTimeout = const Duration(seconds: 30);
    notifyListeners();

    try {
      var completedBytes = 0;
      for (final artifact in profile.artifacts) {
        await _downloadArtifact(profile, artifact, staging, completedBytes);
        completedBytes += artifact.bytes;
      }
      if (_cancelRequested) throw const _DownloadCancelled();

      await File('${staging.path}/install.json').writeAsString(
        jsonEncode({
          'id': profile.id,
          'repository': profile.repository,
          'revision': profile.revision,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
          'artifacts': [
            for (final artifact in profile.artifacts)
              {
                'name': artifact.localName,
                'bytes': artifact.bytes,
                'sha256': artifact.sha256,
              },
          ],
        }),
        flush: true,
      );

      final target = Directory('${root.path}/${profile.id}');
      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);
      _installed.add(profile.id);
      _selectedId = profile.id;
      await _saveState();
      _progress = 1;
    } on _DownloadCancelled {
      _error = null;
    } catch (e) {
      if (_cancelRequested) {
        _error = null;
      } else {
        _activity = ModelActivity.failed;
        _error = _friendlyError(e);
        rethrow;
      }
    } finally {
      _activeClient?.close(force: true);
      _activeClient = null;
      if (await staging.exists()) await staging.delete(recursive: true);
      _activeId = null;
      if (_activity != ModelActivity.failed) _activity = ModelActivity.idle;
      notifyListeners();
    }
    return _selectedId == id && _installed.contains(id);
  }

  void cancelDownload() {
    if (!busy) return;
    _cancelRequested = true;
    _activeClient?.close(force: true);
  }

  void reportRuntimeFailure(Object error) {
    _activity = ModelActivity.failed;
    _error =
        '모델을 실행할 수 없습니다. 다른 모델을 선택해 주세요. '
        '${_friendlyError(error)}';
    notifyListeners();
  }

  Future<void> select(String id) async {
    _profile(id);
    if (!_installed.contains(id)) {
      throw StateError('먼저 모델을 다운로드해 주세요.');
    }
    if (busy) throw StateError('다운로드가 끝난 뒤 모델을 바꿀 수 있습니다.');
    _selectedId = id;
    _error = null;
    await _saveState();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _profile(id);
    if (_activeId == id) throw StateError('다운로드 중인 모델입니다.');
    final target = Directory('${_requireRoot().path}/$id');
    if (await target.exists()) await target.delete(recursive: true);
    _installed.remove(id);
    if (_selectedId == id) _selectedId = null;
    await _saveState();
    notifyListeners();
  }

  Future<void> _downloadArtifact(
    EmbeddingModel profile,
    ModelArtifact artifact,
    Directory staging,
    int completedBytes,
  ) async {
    final client = _activeClient!;
    final uri = _downloadUriResolver(profile, artifact);
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Noteez/1.0 model-manager',
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Hugging Face가 HTTP ${response.statusCode}을 반환했습니다.',
        uri: uri,
      );
    }

    final file = File('${staging.path}/${artifact.localName}');
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        if (_cancelRequested) throw const _DownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        _setProgress((completedBytes + received) / profile.downloadBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (_cancelRequested) throw const _DownloadCancelled();

    _activity = ModelActivity.verifying;
    notifyListeners();
    if (received != artifact.bytes) {
      throw StateError(
        '${artifact.localName} 크기가 예상과 다릅니다 '
        '(${received}B / ${artifact.bytes}B).',
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (_cancelRequested) throw const _DownloadCancelled();
    if (digest.toString() != artifact.sha256) {
      throw StateError('${artifact.localName} 무결성 검증에 실패했습니다.');
    }
    _activity = ModelActivity.downloading;
  }

  void _setProgress(double value) {
    _progress = value.clamp(0, 1);
    final percent = (_progress * 1000).floor();
    if (percent == _lastProgressNotification) return;
    _lastProgressNotification = percent;
    notifyListeners();
  }

  void _scanInstalled() {
    _installed.clear();
    final root = _requireRoot();
    for (final profile in catalog) {
      final dir = Directory('${root.path}/${profile.id}');
      final manifest = File('${dir.path}/install.json');
      if (!manifest.existsSync()) continue;
      try {
        final value = jsonDecode(manifest.readAsStringSync());
        if (value is! Map<String, dynamic> ||
            value['id'] != profile.id ||
            value['revision'] != profile.revision) {
          continue;
        }
        final artifacts = (value['artifacts'] as List?)
            ?.cast<Map<String, dynamic>>();
        if (artifacts == null || artifacts.length != profile.artifacts.length) {
          continue;
        }
        final manifestHashes = {
          for (final artifact in artifacts)
            artifact['name'] as String: artifact['sha256'] as String,
        };
        if (profile.artifacts.any(
          (artifact) => manifestHashes[artifact.localName] != artifact.sha256,
        )) {
          continue;
        }
      } catch (_) {
        continue;
      }
      final valid = profile.artifacts.every((artifact) {
        final file = File('${dir.path}/${artifact.localName}');
        return file.existsSync() && file.lengthSync() == artifact.bytes;
      });
      if (valid) _installed.add(profile.id);
    }
  }

  Future<void> _loadState() async {
    final file = File('${_requireRoot().path}/state.json');
    if (!await file.exists()) return;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic>) {
        _selectedId = value['selectedId'] as String?;
      }
    } catch (_) {
      _selectedId = null;
    }
  }

  Future<void> _loadCustomCatalog() async {
    _catalog
      ..clear()
      ..addAll(_builtInCatalog);
    final file = File('${_requireRoot().path}/catalog.json');
    if (!await file.exists()) return;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! List) return;
      for (final item in value) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final profile = EmbeddingModel.fromJson(item);
          _validateCustomProfile(profile);
          if (_catalog.every((model) => model.id != profile.id)) {
            _catalog.add(profile);
          }
        } catch (_) {
          // 손상되거나 이전 버전 형식인 한 항목 때문에 전체 카탈로그를 버리지 않는다.
        }
      }
    } catch (_) {
      // 다음 등록 때 유효한 카탈로그로 다시 쓴다.
    }
  }

  Future<void> _saveCustomCatalog() async {
    final root = _requireRoot();
    final target = File('${root.path}/catalog.json');
    final temporary = File('${root.path}/.catalog.json.partial');
    final builtInIds = {for (final model in _builtInCatalog) model.id};
    await temporary.writeAsString(
      jsonEncode([
        for (final model in _catalog)
          if (!builtInIds.contains(model.id)) model.toJson(),
      ]),
      flush: true,
    );
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<void> _saveState() async {
    final root = _requireRoot();
    final target = File('${root.path}/state.json');
    final temporary = File('${root.path}/.state.json.partial');
    await temporary.writeAsString(
      jsonEncode({'selectedId': _selectedId}),
      flush: true,
    );
    await temporary.rename(target.path);
  }

  Directory _requireRoot() {
    final root = _root;
    if (root == null) throw StateError('ModelManager.initialize()가 필요합니다.');
    return root;
  }

  EmbeddingModel _profile(String id) {
    for (final profile in catalog) {
      if (profile.id == id) return profile;
    }
    throw ArgumentError.value(id, 'id', '지원하지 않는 모델입니다.');
  }

  void _validateCustomProfile(EmbeddingModel profile) {
    final safeId = RegExp(r'^hf-[a-f0-9]{16}$');
    final repository = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
    final revision = RegExp(r'^[a-f0-9]{40,64}$');
    final hash = RegExp(r'^[a-f0-9]{64}$');
    const allowedLicenses = {
      'mit',
      'apache-2.0',
      'bsd-2-clause',
      'bsd-3-clause',
      'cc-by-4.0',
    };
    if (!safeId.hasMatch(profile.id) ||
        !repository.hasMatch(profile.repository) ||
        !revision.hasMatch(profile.revision) ||
        profile.verified ||
        profile.recommended ||
        !allowedLicenses.contains(profile.license.toLowerCase()) ||
        profile.dimensions < 1 ||
        profile.dimensions > 1024) {
      throw ArgumentError('안전한 Noteez 호환 모델 프로필이 아닙니다.');
    }
    if (profile.artifacts.length != 2 ||
        profile.downloadBytes <= 0 ||
        profile.downloadBytes > 1536 * 1024 * 1024) {
      throw ArgumentError('모델 파일 구성이나 크기를 지원하지 않습니다.');
    }
    final names = <String>{};
    for (final artifact in profile.artifacts) {
      if (!names.add(artifact.localName) ||
          !const {
            'model.onnx',
            'tokenizer.json',
          }.contains(artifact.localName) ||
          artifact.bytes <= 0 ||
          artifact.bytes > 1536 * 1024 * 1024 ||
          !hash.hasMatch(artifact.sha256) ||
          artifact.remotePath.startsWith('/') ||
          artifact.remotePath.split('/').contains('..')) {
        throw ArgumentError('모델 파일 정보가 안전하지 않습니다.');
      }
    }
    if (!names.containsAll(const {'model.onnx', 'tokenizer.json'})) {
      throw ArgumentError('ONNX 모델과 tokenizer.json이 모두 필요합니다.');
    }
  }

  String _friendlyError(Object error) {
    if (error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException) {
      return '네트워크 연결을 확인해 주세요.';
    }
    if (error is HttpException) return error.message;
    if (error is FileSystemException) return '모델을 저장할 수 없습니다.';
    return error.toString().replaceFirst('Bad state: ', '');
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
