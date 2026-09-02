import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/huggingface_model_search.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      Object response;
      switch (request.uri.path) {
        case '/api/models':
          response = [
            {
              'id': 'community/multilingual-e5-noteez',
              'tags': ['onnx', 'sentence-transformers'],
            },
            {
              'id': 'community/multilingual-e5-custom-code',
              'tags': ['onnx', 'sentence-transformers', 'custom_code'],
            },
          ];
        case '/api/models/community/multilingual-e5-noteez':
          response = {
            'id': 'community/multilingual-e5-noteez',
            'sha': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'tags': ['onnx', 'sentence-transformers', 'license:apache-2.0'],
            'cardData': {'license': 'apache-2.0'},
            'siblings': [
              {
                'rfilename': 'onnx/model_qint8.onnx',
                'size': 120000000,
                'lfs': {
                  'size': 120000000,
                  'sha256': List.filled(64, '1').join(),
                },
              },
              {
                'rfilename': 'onnx/tokenizer.json',
                'size': 17000000,
                'lfs': {
                  'size': 17000000,
                  'sha256': List.filled(64, '2').join(),
                },
              },
              {'rfilename': 'onnx/config.json'},
            ],
          };
        case '/community/multilingual-e5-noteez/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/onnx/config.json':
          response = {
            'hidden_size': 384,
            'max_position_embeddings': 512,
            'tokenizer_class': 'XLMRobertaTokenizer',
          };
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('returns only hash-pinned multilingual E5 ONNX profiles', () async {
    final search = HuggingFaceModelSearch(
      origin: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    final result = await search.search('multilingual-e5');

    expect(result.checked, 1);
    expect(result.models, hasLength(1));
    final model = result.models.single;
    expect(model.id, matches(RegExp(r'^hf-[a-f0-9]{16}$')));
    expect(model.repository, 'community/multilingual-e5-noteez');
    expect(model.revision, List.filled(40, 'a').join());
    expect(model.dimensions, 384);
    expect(model.license, 'apache-2.0');
    expect(model.artifacts.map((file) => file.localName), [
      'model.onnx',
      'tokenizer.json',
    ]);
  });
}
