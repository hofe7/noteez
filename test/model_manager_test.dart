import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/model_manager.dart';
import 'package:noteez/models/model_catalog.dart';

void main() {
  late Directory support;
  late HttpServer server;
  final files = <String, List<int>>{
    'model.onnx': utf8.encode('small fake onnx model'),
    'tokenizer.json': utf8.encode('{"model":{"vocab":[]}}'),
  };

  EmbeddingModel profile({String? modelHash}) => EmbeddingModel(
    id: 'test-model',
    name: 'Test model',
    description: 'fixture',
    badge: 'test',
    repository: 'fixture/model',
    revision: 'fixed-revision',
    dimensions: 3,
    artifacts: [
      ModelArtifact(
        remotePath: 'model.onnx',
        localName: 'model.onnx',
        bytes: files['model.onnx']!.length,
        sha256: modelHash ?? sha256.convert(files['model.onnx']!).toString(),
      ),
      ModelArtifact(
        remotePath: 'tokenizer.json',
        localName: 'tokenizer.json',
        bytes: files['tokenizer.json']!.length,
        sha256: sha256.convert(files['tokenizer.json']!).toString(),
      ),
    ],
  );

  ModelManager manager(EmbeddingModel model) => ModelManager(
    supportDirectory: () async => support,
    catalog: [model],
    downloadUriResolver: (_, artifact) => Uri.parse(
      'http://${server.address.host}:${server.port}/${artifact.localName}',
    ),
  );

  setUp(() async {
    support = await Directory.systemTemp.createTemp('noteez-model-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final name = request.uri.pathSegments.single;
      final bytes = files[name];
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await support.delete(recursive: true);
  });

  test('downloads, verifies, persists, selects, and removes a model', () async {
    final model = profile();
    final first = manager(model);
    await first.initialize();

    await first.downloadAndSelect(model.id);

    expect(first.isInstalled(model.id), isTrue);
    expect(first.selectedId, model.id);
    expect(
      await File(first.selectedModel!.modelPath).readAsBytes(),
      files['model.onnx'],
    );
    expect(
      await File(first.selectedModel!.tokenizerPath).readAsBytes(),
      files['tokenizer.json'],
    );

    final reloaded = manager(model);
    await reloaded.initialize();
    expect(reloaded.selectedId, model.id);
    expect(reloaded.selectedModel, isNotNull);

    await reloaded.remove(model.id);
    expect(reloaded.selectedId, isNull);
    expect(reloaded.isInstalled(model.id), isFalse);
  });

  test('does not install an artifact with the wrong hash', () async {
    final model = profile(modelHash: List.filled(64, '0').join());
    final subject = manager(model);
    await subject.initialize();

    await expectLater(subject.downloadAndSelect(model.id), throwsStateError);

    expect(subject.isInstalled(model.id), isFalse);
    expect(subject.selectedId, isNull);
    final root = Directory('${support.path}/models');
    expect(
      root.listSync().whereType<Directory>().where(
        (entry) => entry.path.contains('.partial-'),
      ),
      isEmpty,
    );
  });

  test(
    'cancels an in-progress download without installing partial files',
    () async {
      await server.close(force: true);
      final payload = List<int>.generate(1024 * 1024, (index) => index % 251);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.contentLength = payload.length;
        try {
          for (var offset = 0; offset < payload.length; offset += 4096) {
            final end = offset + 4096 < payload.length
                ? offset + 4096
                : payload.length;
            request.response.add(payload.sublist(offset, end));
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }
        } catch (_) {
          // Client cancellation closes the response while the fixture is sending.
        } finally {
          try {
            await request.response.close();
          } catch (_) {
            // Already closed by client cancellation.
          }
        }
      });
      final model = EmbeddingModel(
        id: 'slow-model',
        name: 'Slow model',
        description: 'fixture',
        badge: 'test',
        repository: 'fixture/slow',
        revision: 'fixed-revision',
        dimensions: 3,
        artifacts: [
          ModelArtifact(
            remotePath: 'model.onnx',
            localName: 'model.onnx',
            bytes: payload.length,
            sha256: sha256.convert(payload).toString(),
          ),
        ],
      );
      final subject = manager(model);
      await subject.initialize();

      final download = subject.downloadAndSelect(model.id);
      while (!subject.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      subject.cancelDownload();

      expect(await download, isFalse);
      expect(subject.isInstalled(model.id), isFalse);
      expect(subject.selectedId, isNull);
    },
  );

  test('persists a validated Hugging Face profile across restarts', () async {
    final dynamic = EmbeddingModel(
      id: 'hf-0123456789abcdef',
      name: 'Community E5',
      description: 'fixture',
      badge: 'community',
      repository: 'fixture/multilingual-e5',
      revision: List.filled(40, 'a').join(),
      dimensions: 384,
      license: 'apache-2.0',
      artifacts: [
        ModelArtifact(
          remotePath: 'onnx/model_qint8.onnx',
          localName: 'model.onnx',
          bytes: files['model.onnx']!.length,
          sha256: sha256.convert(files['model.onnx']!).toString(),
        ),
        ModelArtifact(
          remotePath: 'onnx/tokenizer.json',
          localName: 'tokenizer.json',
          bytes: files['tokenizer.json']!.length,
          sha256: sha256.convert(files['tokenizer.json']!).toString(),
        ),
      ],
    );
    final first = manager(profile());
    await first.initialize();
    await first.registerCompatibleModel(dynamic);
    await first.downloadAndSelect(dynamic.id);

    final reloaded = manager(profile());
    await reloaded.initialize();
    expect(reloaded.catalog.map((model) => model.id), contains(dynamic.id));
    expect(reloaded.selectedId, dynamic.id);
    expect(reloaded.selectedModel?.profile.repository, dynamic.repository);

    await reloaded.remove(dynamic.id);
    expect(reloaded.isInstalled(dynamic.id), isFalse);
    expect(reloaded.catalog.map((model) => model.id), contains(dynamic.id));
  });

  test('rejects unsafe dynamic model profiles', () async {
    final subject = manager(profile());
    await subject.initialize();
    final unsafe = EmbeddingModel(
      id: 'owner/model',
      name: 'Unsafe',
      description: 'fixture',
      badge: 'test',
      repository: 'owner/model',
      revision: List.filled(40, 'a').join(),
      dimensions: 384,
      artifacts: [
        ModelArtifact(
          remotePath: '../model.onnx',
          localName: 'model.onnx',
          bytes: 10,
          sha256: List.filled(64, '0').join(),
        ),
      ],
    );

    await expectLater(
      subject.registerCompatibleModel(unsafe),
      throwsArgumentError,
    );
  });
}
