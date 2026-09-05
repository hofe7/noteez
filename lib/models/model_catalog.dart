class ModelArtifact {
  const ModelArtifact({
    required this.remotePath,
    required this.localName,
    required this.bytes,
    required this.sha256,
  });

  final String remotePath;
  final String localName;
  final int bytes;
  final String sha256;

  factory ModelArtifact.fromJson(Map<String, dynamic> json) => ModelArtifact(
    remotePath: json['remotePath'] as String,
    localName: json['localName'] as String,
    bytes: json['bytes'] as int,
    sha256: json['sha256'] as String,
  );

  Map<String, dynamic> toJson() => {
    'remotePath': remotePath,
    'localName': localName,
    'bytes': bytes,
    'sha256': sha256,
  };
}

/// Noteez가 실제 입력/출력 구조까지 검증한 임베딩 모델.
///
/// 파일은 원 제작자의 Hugging Face 저장소에서 직접 받는다. `main` 대신 고정
/// revision과 SHA-256을 사용해 저장소가 바뀌어도 같은 모델만 설치되게 한다.
class EmbeddingModel {
  const EmbeddingModel({
    required this.id,
    required this.name,
    required this.description,
    required this.badge,
    required this.repository,
    required this.revision,
    required this.dimensions,
    required this.artifacts,
    this.license = 'MIT',
    this.verified = false,
    this.recommended = false,
  });

  final String id;
  final String name;
  final String description;
  final String badge;
  final String repository;
  final String revision;
  final int dimensions;
  final List<ModelArtifact> artifacts;
  final String license;
  final bool verified;
  final bool recommended;

  int get downloadBytes => artifacts.fold(0, (sum, file) => sum + file.bytes);

  Uri downloadUri(ModelArtifact artifact) => Uri.parse(
    'https://huggingface.co/$repository/resolve/$revision/'
    '${artifact.remotePath}?download=true',
  );

  String get sourceUrl => 'https://huggingface.co/$repository';

  factory EmbeddingModel.fromJson(Map<String, dynamic> json) => EmbeddingModel(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    badge: json['badge'] as String,
    repository: json['repository'] as String,
    revision: json['revision'] as String,
    dimensions: json['dimensions'] as int,
    artifacts: (json['artifacts'] as List)
        .cast<Map<String, dynamic>>()
        .map(ModelArtifact.fromJson)
        .toList(growable: false),
    license: json['license'] as String? ?? 'unknown',
    verified: json['verified'] == true,
    recommended: json['recommended'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'badge': badge,
    'repository': repository,
    'revision': revision,
    'dimensions': dimensions,
    'downloadBytes': downloadBytes,
    'artifacts': [for (final artifact in artifacts) artifact.toJson()],
    'recommended': recommended,
    'verified': verified,
    'sourceUrl': sourceUrl,
    'license': license,
  };
}

abstract final class ModelCatalog {
  static const models = <EmbeddingModel>[
    EmbeddingModel(
      id: 'multilingual-e5-small-qint8',
      name: 'Multilingual E5 Small',
      description: '빠르고 가벼운 기본 모델 · 한국어 포함 94개 언어',
      badge: '균형',
      repository: 'intfloat/multilingual-e5-small',
      revision: '614241f622f53c4eeff9890bdc4f31cfecc418b3',
      dimensions: 384,
      verified: true,
      recommended: true,
      artifacts: [
        ModelArtifact(
          remotePath: 'onnx/model_qint8_avx512_vnni.onnx',
          localName: 'model.onnx',
          bytes: 118346824,
          sha256:
              'dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88',
        ),
        ModelArtifact(
          remotePath: 'onnx/tokenizer.json',
          localName: 'tokenizer.json',
          bytes: 17082730,
          sha256:
              '0b44a9d7b51c3c62626640cda0e2c2f70fdacdc25bbbd68038369d14ebdf4c39',
        ),
      ],
    ),
    EmbeddingModel(
      id: 'multilingual-e5-base-qint8',
      name: 'Multilingual E5 Base',
      description: '더 큰 임베딩 모델 · 메모와 언어에 따라 품질 차이를 비교해 보세요',
      badge: '대형',
      repository: 'intfloat/multilingual-e5-base',
      revision: 'd128750597153bb5987e10b1c3493a34e5a4502a',
      dimensions: 768,
      verified: true,
      artifacts: [
        ModelArtifact(
          remotePath: 'onnx/model_qint8_avx512_vnni.onnx',
          localName: 'model.onnx',
          bytes: 278686411,
          sha256:
              '2523551878658b305550d8759443822dbfda9ed9c8012ef2c354ba2c5b9de503',
        ),
        ModelArtifact(
          remotePath: 'onnx/tokenizer.json',
          localName: 'tokenizer.json',
          bytes: 17082660,
          sha256:
              '62c24cdc13d4c9952d63718d6c9fa4c287974249e16b7ade6d5a85e7bbb75626',
        ),
      ],
    ),
  ];

  static EmbeddingModel? byId(String? id) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }
}
