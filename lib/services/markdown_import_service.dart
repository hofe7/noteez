import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/sticky.dart';
import '../markdown/markdown_portability.dart';
import '../markdown/import_merge.dart';
import '../link_graph.dart';
import 'group_service.dart';

typedef ImportSummary = ({
  int imported,
  int updated,
  int skipped,
  int conflicted,
  int linked,
  int failed,
});

class MarkdownImportFailure implements Exception {
  const MarkdownImportFailure(this.cause);
  final Object cause;
  @override
  String toString() => '가져오기를 저장하지 못했어요. 이번 메모·연결·묶음 변경을 취소했으니 다시 시도해 주세요.';
}

/// A batch either commits notes, origins, links and groups together, or none.
/// It reads current DB state under the same transaction used for writing.
class MarkdownImportService {
  MarkdownImportService(this._db, {required this.documentHash});
  final AppDatabase _db;
  final String Function(Sticky) documentHash;
  final _markdown = MarkdownPortability();
  late final _groups = GroupService(_db);

  Future<ImportSummary> store(MarkdownImportBatch batch) => _db
      .groupTransaction(() async {
        final stickies = await _db.allActive();
        final usedIds = (await _db.select(_db.stickies).get())
            .map((n) => n.id)
            .toSet();
        final noteGroups = await _db.allActiveGroups();
        Sticky? stickyOf(String id) {
          for (final note in stickies) {
            if (note.id == id) return note;
          }
          return null;
        }

        final graph = LinkGraph();
        for (final link in await _db.allActiveLinks()) {
          graph.addEdge(link.aId, link.bId);
        }
        Future<bool> linkPair(String a, String b) async {
          if (a == b || graph.neighbors(a).contains(b)) return false;
          await _db.insertLink(
            const Uuid().v4(),
            a,
            b,
            DateTime.now().millisecondsSinceEpoch,
          );
          graph.addEdge(a, b);
          return true;
        }

        Sticky makeImportedSticky(ImportedMarkdownNote note, {String? id}) =>
            newImportedSticky(note, stickies.length, id: id);
        final bySourcePath = <String, String>{};
        final importedGroups =
            <String, ({String? groupId, String? groupName})>{};
        var imported = 0;
        var updated = 0;
        var skipped = 0;
        var conflicted = 0;
        for (final note in batch.notes) {
          final origin = await _db.importOrigin(note.sourceKey);
          final existing = origin == null ? null : stickyOf(origin.stickyId);
          var updateOrigin = true;
          Sticky sticky;
          final decision = decideMarkdownImport(
            hasOrigin: origin != null,
            hasSticky: existing != null,
            isBeingEdited: existing?.open == true,
            sourceUnchanged: origin?.sourceHash == note.sourceHash,
            stickyUnchangedSinceImport:
                origin != null &&
                existing != null &&
                documentHash(existing) == origin.stickyHash,
          );
          if (decision == MarkdownImportDecision.skip) {
            sticky = existing!;
            skipped++;
            // 같은 원본을 다시 고른 것뿐이다. 사용자가 Noteez에서 편집했더라도
            // 최초 import 시점의 stickyHash를 유지해야 다음 원본 변경 때 덮어쓰기
            // 여부를 정확히 판정할 수 있다.
            updateOrigin = false;
          } else if (decision == MarkdownImportDecision.update) {
            sticky = existing!.copyWith(
              blocks: _importBlocks(note),
              updatedAt: note.metadata.updatedAt ?? DateTime.now(),
            );
            await _db.updateExisting(sticky);
            stickies[stickies.indexWhere((n) => n.id == sticky.id)] = sticky;
            updated++;
          } else if (decision == MarkdownImportDecision.preserveBoth) {
            sticky = makeImportedSticky(note);
            await _db.upsert(sticky);
            usedIds.add(sticky.id);
            stickies.add(sticky);
            imported++;
            conflicted++;
          } else {
            final externalId = note.metadata.noteezId;
            final sameId = externalId == null ? null : stickyOf(externalId);
            if (sameId != null &&
                documentHash(sameId) ==
                    documentHash(makeImportedSticky(note, id: externalId))) {
              sticky = sameId;
              skipped++;
            } else {
              sticky = makeImportedSticky(
                note,
                id: externalId != null && !usedIds.contains(externalId)
                    ? externalId
                    : null,
              );
              await _db.upsert(sticky);
              usedIds.add(sticky.id);
              stickies.add(sticky);
              imported++;
            }
          }
          bySourcePath[note.sourcePath] = sticky.id;
          if (decision != MarkdownImportDecision.skip &&
              (note.metadata.noteezGroupId != null ||
                  note.metadata.noteezGroupName != null)) {
            importedGroups[sticky.id] = (
              groupId: note.metadata.noteezGroupId,
              groupName: note.metadata.noteezGroupName,
            );
          }
          if (updateOrigin) {
            await _db.upsertImportOrigin(
              sourceKey: note.sourceKey,
              stickyId: sticky.id,
              sourceHash: note.sourceHash,
              stickyHash: documentHash(sticky),
            );
          }
        }

        var linked = 0;
        for (final link in batch.links) {
          final a = bySourcePath[link.sourcePath];
          final b = bySourcePath[link.targetPath];
          if (a != null && b != null && await linkPair(a, b)) linked++;
        }
        // 한 파일만 가져온 경우에도 [[기존 메모]] / Existing.md 링크를 복원한다.
        // 같은 제목이 둘 이상이면 모호하므로 자동 연결하지 않는다.
        final idsByTitle = <String, List<String>>{};
        for (final sticky in stickies) {
          final title = sticky.preview.trim().toLowerCase();
          if (title.isNotEmpty) (idsByTitle[title] ??= []).add(sticky.id);
        }
        for (final note in batch.notes) {
          final sourceId = bySourcePath[note.sourcePath];
          if (sourceId == null) continue;
          for (final reference in note.references) {
            final title = _markdown.referenceTitle(reference).toLowerCase();
            final candidates = idsByTitle[title];
            if (candidates?.length == 1 &&
                await linkPair(sourceId, candidates!.single)) {
              linked++;
            }
          }
        }

        final restoredGroupIds = <String, String>{};
        for (final entry in importedGroups.entries) {
          final metadata = entry.value;
          final sourceKey = metadata.groupId?.trim().isNotEmpty == true
              ? 'id:${metadata.groupId!.trim()}'
              : 'name:${(metadata.groupName ?? '').trim().toLowerCase()}';
          var groupId = restoredGroupIds[sourceKey];
          if (groupId == null) {
            final requestedId = metadata.groupId?.trim();
            NoteGroupRow? existing;
            for (final group in noteGroups) {
              if ((requestedId?.isNotEmpty == true &&
                      group.id == requestedId) ||
                  (requestedId?.isNotEmpty != true &&
                      group.name.toLowerCase() ==
                          (metadata.groupName ?? '').trim().toLowerCase())) {
                existing = group;
                break;
              }
            }
            groupId = existing?.id;
            groupId ??= await _groups.importGroup(
              metadata.groupName ?? '가져온 묶음',
              requestedId: requestedId,
            );
            restoredGroupIds[sourceKey] = groupId;
          }
          await _db.assignNotesToGroup(groupId, [entry.key]);
        }
        return (
          imported: imported,
          updated: updated,
          skipped: skipped,
          conflicted: conflicted,
          linked: linked,
          failed: batch.failedPaths.length,
        );
      })
      .catchError((Object error, StackTrace stack) {
        Error.throwWithStackTrace(MarkdownImportFailure(error), stack);
      });

  List<Block> _importBlocks(ImportedMarkdownNote note) =>
      note.blocks.isEmpty ? [textBlock(note.title)] : note.blocks;

  Sticky newImportedSticky(ImportedMarkdownNote note, int n, {String? id}) {
    final now = DateTime.now();
    return Sticky(
      id: id ?? const Uuid().v4(),
      blocks: _importBlocks(note),
      colorIndex: (note.metadata.colorIndex ?? n % 6).clamp(0, 5),
      x: 200 + n * 26.0,
      y: 180 + n * 26.0,
      open: false,
      createdAt: note.metadata.createdAt ?? now,
      updatedAt: note.metadata.updatedAt ?? now,
    );
  }
}
