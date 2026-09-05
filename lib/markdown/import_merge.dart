/// 같은 외부 Markdown 원본을 다시 가져올 때의 안전한 병합 판단.
enum MarkdownImportDecision { create, skip, update, preserveBoth }

MarkdownImportDecision decideMarkdownImport({
  required bool hasOrigin,
  required bool hasSticky,
  required bool sourceUnchanged,
  required bool stickyUnchangedSinceImport,
  bool isBeingEdited = false,
}) {
  if (!hasOrigin || !hasSticky) return MarkdownImportDecision.create;
  if (sourceUnchanged) return MarkdownImportDecision.skip;
  if (isBeingEdited) return MarkdownImportDecision.preserveBoth;
  if (stickyUnchangedSinceImport) return MarkdownImportDecision.update;
  return MarkdownImportDecision.preserveBoth;
}
