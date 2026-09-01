import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/markdown/import_merge.dart';

void main() {
  test('new source creates a note', () {
    expect(
      decideMarkdownImport(
        hasOrigin: false,
        hasSticky: false,
        sourceUnchanged: false,
        stickyUnchangedSinceImport: false,
      ),
      MarkdownImportDecision.create,
    );
  });

  test('unchanged source is skipped even when local note was edited', () {
    expect(
      decideMarkdownImport(
        hasOrigin: true,
        hasSticky: true,
        sourceUnchanged: true,
        stickyUnchangedSinceImport: false,
      ),
      MarkdownImportDecision.skip,
    );
  });

  test('changed source updates an untouched imported note', () {
    expect(
      decideMarkdownImport(
        hasOrigin: true,
        hasSticky: true,
        sourceUnchanged: false,
        stickyUnchangedSinceImport: true,
      ),
      MarkdownImportDecision.update,
    );
  });

  test('changed source preserves both when local note also changed', () {
    expect(
      decideMarkdownImport(
        hasOrigin: true,
        hasSticky: true,
        sourceUnchanged: false,
        stickyUnchangedSinceImport: false,
      ),
      MarkdownImportDecision.preserveBoth,
    );
  });
}
