import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/models/model_catalog.dart';

void main() {
  test('catalog pins every Hugging Face artifact by revision and hash', () {
    expect(ModelCatalog.models.map((model) => model.id).toSet(), hasLength(2));

    for (final model in ModelCatalog.models) {
      expect(model.revision, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(
        model.downloadUri(model.artifacts.first).path,
        contains(model.revision),
      );
      expect(
        model.downloadUri(model.artifacts.first).path,
        isNot(contains('/main/')),
      );
      expect(model.downloadBytes, greaterThan(100 * 1024 * 1024));
      for (final artifact in model.artifacts) {
        expect(artifact.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(artifact.bytes, greaterThan(0));
      }
    }
  });
}
