import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/sticky.dart';

part 'database.g.dart';

const databaseSchemaVersion = 12;

/// 스티커 행. sync 친화 설계:
/// - id: UUID (auto-increment 안 씀)
/// - updatedAt: 마지막 수정 (충돌 해결용)
/// - deletedAt: soft delete tombstone (삭제도 동기화되게)
/// blocks 는 일단 JSON 컬럼. 블록 단위 sync 가 필요해지면 별도 테이블로 정규화.
@DataClassName('StickyRow')
class Stickies extends Table {
  TextColumn get id => text()();
  IntColumn get colorIndex => integer()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width =>
      real().withDefault(const Constant(kDefaultStickyWidth))();
  RealColumn get height =>
      real().withDefault(const Constant(kDefaultStickyHeight))();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get open => boolean().withDefault(const Constant(true))();
  IntColumn get remindAt => integer().nullable()(); // 리마인더 시각(millis)
  TextColumn get blocksJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get contentUpdatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 승인된 연결(엣지). 사용자가 "연결"한 두 스티커. 누적되면 지식 그래프.
@DataClassName('LinkRow')
class Links extends Table {
  TextColumn get id => text()();
  TextColumn get aId => text()();
  TextColumn get bId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 메모별 임베딩 캐시. hash(텍스트) 가 같으면 재계산 안 하고 재사용.
@DataClassName('EmbeddingRow')
class Embeddings extends Table {
  TextColumn get stickyId => text()();
  TextColumn get modelId =>
      text().withDefault(const Constant('legacy-bundled-e5'))();
  TextColumn get hash => text()();
  TextColumn get vec =>
      text()(); // Versioned document/chunk JSON (legacy: [double,...])

  @override
  Set<Column> get primaryKey => {stickyId};
}

/// 사용자가 숨긴 의미 추천 pair. 양쪽 메모의 콘텐츠 hash도 함께 저장해 내용이
/// 바뀌면 과거 거절을 자동으로 무효화하고 다시 평가할 수 있다.
@DataClassName('SuggestionDismissalRow')
class SuggestionDismissals extends Table {
  TextColumn get aId => text()();
  TextColumn get bId => text()();
  TextColumn get aHash => text()();
  TextColumn get bHash => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {aId, bId};
}

/// 외부 Markdown 원본과 Noteez 메모의 대응. 같은 파일을 다시 가져올 때 중복을
/// 만들지 않고, Noteez 쪽이 수정되지 않은 경우에만 안전하게 원본 갱신을 반영한다.
@DataClassName('ImportOriginRow')
class ImportOrigins extends Table {
  TextColumn get sourceKey => text()();
  TextColumn get stickyId => text()();
  TextColumn get sourceHash => text()();
  TextColumn get stickyHash => text()();
  IntColumn get importedAt => integer()();

  @override
  Set<Column> get primaryKey => {sourceKey};
}

/// 사용자가 직접 이름 붙여 정리하는 메모 묶음. 연결 그래프와는 별개이며,
/// 묶음을 지워도 메모 자체는 유지한다.
@DataClassName('NoteGroupRow')
class NoteGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 첫 버전은 메모 하나가 하나의 수동 묶음에만 속하도록 한다. stickyId를 PK로
/// 두어 이 제약을 저장소 수준에서도 보장한다.
@DataClassName('GroupMemberRow')
class GroupMembers extends Table {
  TextColumn get stickyId => text()();
  TextColumn get groupId => text()();
  IntColumn get position => integer()();
  IntColumn get addedAt => integer()();

  @override
  Set<Column> get primaryKey => {stickyId};
}

/// Explicit per-group rejection survives text edits until reset by the user.
class GroupSuggestionDismissals extends Table {
  TextColumn get stickyId => text()();
  TextColumn get groupId => text()();
  @override
  Set<Column> get primaryKey => {stickyId, groupId};
}

/// Persistent installation state, included in database backups.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Stickies,
    Links,
    Embeddings,
    SuggestionDismissals,
    ImportOrigins,
    NoteGroups,
    GroupMembers,
    AppSettings,
    GroupSuggestionDismissals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'noteez'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => databaseSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(stickies, stickies.pinned);
      if (from < 3) await m.createTable(links);
      if (from < 4) await m.createTable(embeddings);
      if (from < 5) await m.addColumn(stickies, stickies.open);
      if (from < 6) await m.addColumn(stickies, stickies.remindAt);
      if (from < 7) await m.createTable(suggestionDismissals);
      if (from < 8) await m.createTable(importOrigins);
      if (from < 9) await m.addColumn(embeddings, embeddings.modelId);
      if (from < 10) {
        await m.createTable(noteGroups);
        await m.createTable(groupMembers);
      }
      if (from < 11) {
        await m.addColumn(stickies, stickies.width);
        await m.addColumn(stickies, stickies.height);
      }
      if (from < 12) {
        await m.addColumn(stickies, stickies.contentUpdatedAt);
        await customStatement(
          'UPDATE stickies SET content_updated_at = updated_at',
        );
        await m.createTable(appSettings);
        await m.createTable(groupSuggestionDismissals);
        // An upgraded database has already completed first launch, even empty.
        await into(appSettings).insert(
          AppSettingsCompanion.insert(key: 'welcomeInitialized', value: 'true'),
        );
      }
    },
  );

  Future<void> initializeWelcome() => transaction(() async {
    final initialized = await (select(
      appSettings,
    )..where((t) => t.key.equals('welcomeInitialized'))).getSingleOrNull();
    if (initialized != null) return;
    final anyNote = await (select(stickies)..limit(1)).get();
    if (anyNote.isEmpty) {
      for (final note in seedStickies()) {
        await upsert(note);
      }
    }
    await into(appSettings).insert(
      AppSettingsCompanion.insert(key: 'welcomeInitialized', value: 'true'),
    );
  });

  Future<List<GroupSuggestionDismissal>> allGroupSuggestionDismissals() =>
      select(groupSuggestionDismissals).get();

  Future<void> dismissGroupSuggestion(String stickyId, String groupId) =>
      into(groupSuggestionDismissals).insertOnConflictUpdate(
        GroupSuggestionDismissalsCompanion.insert(
          stickyId: stickyId,
          groupId: groupId,
        ),
      );

  Future<void> resetGroupSuggestions(String groupId) => (delete(
    groupSuggestionDismissals,
  )..where((t) => t.groupId.equals(groupId))).go();

  Future<List<NoteGroupRow>> allActiveGroups() =>
      (select(noteGroups)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  Future<List<GroupMemberRow>> allGroupMembers() =>
      (select(groupMembers)..orderBy([
            (t) => OrderingTerm.asc(t.groupId),
            (t) => OrderingTerm.asc(t.position),
          ]))
          .get();

  Future<void> upsertNoteGroup({
    required String id,
    required String name,
    required int position,
    bool collapsed = false,
    int? createdAt,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return into(noteGroups).insertOnConflictUpdate(
      NoteGroupsCompanion.insert(
        id: id,
        name: name,
        position: position,
        collapsed: Value(collapsed),
        createdAt: createdAt ?? now,
        updatedAt: now,
        deletedAt: const Value(null),
      ),
    );
  }

  Future<void> renameNoteGroup(String id, String name) =>
      (update(noteGroups)..where((t) => t.id.equals(id))).write(
        NoteGroupsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> setNoteGroupCollapsed(String id, bool collapsed) =>
      (update(noteGroups)..where((t) => t.id.equals(id))).write(
        NoteGroupsCompanion(
          collapsed: Value(collapsed),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> softDeleteNoteGroup(String id) => transaction(() async {
    await (update(noteGroups)..where((t) => t.id.equals(id))).write(
      NoteGroupsCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await (delete(groupMembers)..where((t) => t.groupId.equals(id))).go();
  });

  Future<void> assignNotesToGroup(String groupId, Iterable<String> ids) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      final current =
          await (select(groupMembers)
                ..where((t) => t.groupId.equals(groupId))
                ..orderBy([(t) => OrderingTerm.desc(t.position)]))
              .get();
      var position = current.isEmpty ? 0 : current.first.position + 1;
      for (final stickyId in uniqueIds) {
        await into(groupMembers).insertOnConflictUpdate(
          GroupMembersCompanion.insert(
            stickyId: stickyId,
            groupId: groupId,
            position: position++,
            addedAt: now,
          ),
        );
      }
    });
  }

  Future<void> removeNotesFromGroup(Iterable<String> ids) {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) return Future.value();
    return (delete(
      groupMembers,
    )..where((t) => t.stickyId.isIn(uniqueIds))).go();
  }

  /// Restore a multi-note move as one transaction, including undoing creation.
  Future<void> restoreNoteMemberships(
    Map<String, String?> previous, {
    String? deleteGroupId,
  }) => transaction(() async {
    final liveGroups = (await allActiveGroups()).map((g) => g.id).toSet();
    if (previous.values.whereType<String>().any(
      (id) => !liveGroups.contains(id),
    )) {
      throw StateError('이전 묶음이 삭제되어 실행 취소할 수 없습니다.');
    }
    final liveNotes = (await allActive()).map((s) => s.id).toSet();
    if (previous.keys.any((id) => !liveNotes.contains(id))) {
      throw StateError('메모가 삭제되어 실행 취소할 수 없습니다.');
    }
    await removeNotesFromGroup(previous.keys);
    for (final groupId in previous.values.whereType<String>().toSet()) {
      await assignNotesToGroup(
        groupId,
        previous.keys.where((id) => previous[id] == groupId),
      );
    }
    if (deleteGroupId != null) {
      // Another window may have added notes since creation. Keep that group.
      final remaining = await (select(
        groupMembers,
      )..where((t) => t.groupId.equals(deleteGroupId))).get();
      if (remaining.isEmpty) await softDeleteNoteGroup(deleteGroupId);
    }
  });

  Future<void> deleteGroupMembershipForNote(String id) =>
      (delete(groupMembers)..where((t) => t.stickyId.equals(id))).go();

  Future<List<EmbeddingRow>> allEmbeddingsForModel(String modelId) =>
      (select(embeddings)..where((t) => t.modelId.equals(modelId))).get();

  Future<void> upsertEmbedding(
    String id,
    String modelId,
    String hash,
    String vec,
  ) => into(embeddings).insertOnConflictUpdate(
    EmbeddingsCompanion.insert(
      stickyId: id,
      modelId: Value(modelId),
      hash: hash,
      vec: vec,
    ),
  );

  Future<void> deleteEmbedding(String id) =>
      (delete(embeddings)..where((t) => t.stickyId.equals(id))).go();

  Future<void> deleteAllEmbeddings() => delete(embeddings).go();

  Future<List<LinkRow>> allActiveLinks() =>
      (select(links)..where((t) => t.deletedAt.isNull())).get();

  Future<void> insertLink(String id, String a, String b, int createdAt) => into(
    links,
  ).insert(LinksCompanion.insert(id: id, aId: a, bId: b, createdAt: createdAt));

  Future<void> softDeleteLinkBetween(String a, String b) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(links)..where(
          (t) =>
              t.deletedAt.isNull() &
              ((t.aId.equals(a) & t.bId.equals(b)) |
                  (t.aId.equals(b) & t.bId.equals(a))),
        ))
        .write(LinksCompanion(deletedAt: Value(now)));
  }

  Future<void> softDeleteLinksFor(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(links)..where(
          (t) => t.deletedAt.isNull() & (t.aId.equals(id) | t.bId.equals(id)),
        ))
        .write(LinksCompanion(deletedAt: Value(now)));
  }

  Future<List<SuggestionDismissalRow>> allSuggestionDismissals() =>
      select(suggestionDismissals).get();

  Future<void> upsertSuggestionDismissal({
    required String aId,
    required String bId,
    required String aHash,
    required String bHash,
  }) => into(suggestionDismissals).insertOnConflictUpdate(
    SuggestionDismissalsCompanion.insert(
      aId: aId,
      bId: bId,
      aHash: aHash,
      bHash: bHash,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  Future<void> deleteSuggestionDismissalsFor(String id) => (delete(
    suggestionDismissals,
  )..where((t) => t.aId.equals(id) | t.bId.equals(id))).go();

  Future<ImportOriginRow?> importOrigin(String sourceKey) => (select(
    importOrigins,
  )..where((t) => t.sourceKey.equals(sourceKey))).getSingleOrNull();

  Future<void> upsertImportOrigin({
    required String sourceKey,
    required String stickyId,
    required String sourceHash,
    required String stickyHash,
  }) => into(importOrigins).insertOnConflictUpdate(
    ImportOriginsCompanion.insert(
      sourceKey: sourceKey,
      stickyId: stickyId,
      sourceHash: sourceHash,
      stickyHash: stickyHash,
      importedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  Future<void> deleteImportOriginsFor(String stickyId) =>
      (delete(importOrigins)..where((t) => t.stickyId.equals(stickyId))).go();

  /// 삭제 안 된 스티커 전부.
  Future<List<Sticky>> allActive() async {
    final rows = await (select(
      stickies,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsert(Sticky s) {
    return into(stickies).insertOnConflictUpdate(
      StickiesCompanion.insert(
        id: s.id,
        colorIndex: s.colorIndex,
        x: s.x,
        y: s.y,
        width: Value(s.width),
        height: Value(s.height),
        collapsed: Value(s.collapsed),
        pinned: Value(s.pinned),
        open: Value(s.open),
        remindAt: Value(s.remindAt),
        blocksJson: jsonEncode(s.blocks.map((b) => b.toJson()).toList()),
        createdAt: s.createdAt.millisecondsSinceEpoch,
        updatedAt: s.updatedAt.millisecondsSinceEpoch,
        contentUpdatedAt: Value(s.contentUpdatedAt.millisecondsSinceEpoch),
        // Noteez Markdown round-trip으로 과거 ID를 복원할 수 있다. 기존 행이
        // tombstone이면 upsert와 함께 활성 상태로 되돌린다.
        deletedAt: const Value(null),
      ),
    );
  }

  Future<void> softDelete(String id) {
    return (update(stickies)..where((t) => t.id.equals(id))).write(
      StickiesCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<StickyRow>> allTrashed() =>
      (select(stickies)
            ..where((t) => t.deletedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
          .get();

  /// Delete-related changes commit together, before the UI drops the note.
  Future<void> trashNote(String id) => transaction(() async {
    await softDelete(id);
    await deleteEmbedding(id);
    await softDeleteLinksFor(id);
    await deleteSuggestionDismissalsFor(id);
    await deleteImportOriginsFor(id);
    await deleteGroupMembershipForNote(id);
  });

  Future<Sticky?> restoreTrashed(String id) => transaction(() async {
    final count =
        await (update(
          stickies,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())).write(
          const StickiesCompanion(
            deletedAt: Value(null),
            open: Value(false),
            remindAt: Value(null),
          ),
        );
    if (count == 0) return null;
    return _toModel(
      await (select(stickies)..where((t) => t.id.equals(id))).getSingle(),
    );
  });

  /// Active notes cannot be permanently removed through the trash API.
  Future<void> permanentlyDeleteTrashed(String id) => transaction(() async {
    final row =
        await (select(stickies)
              ..where((t) => t.id.equals(id) & t.deletedAt.isNotNull()))
            .getSingleOrNull();
    if (row == null) return;
    await trashNote(id);
    await (delete(
      groupSuggestionDismissals,
    )..where((t) => t.stickyId.equals(id))).go();
    await (delete(
      links,
    )..where((t) => t.aId.equals(id) | t.bId.equals(id))).go();
    await (delete(stickies)..where((t) => t.id.equals(id))).go();
  });

  static Sticky _toModel(StickyRow r) => Sticky(
    id: r.id,
    colorIndex: r.colorIndex,
    x: r.x,
    y: r.y,
    width: r.width,
    height: r.height,
    collapsed: r.collapsed,
    pinned: r.pinned,
    open: r.open,
    remindAt: r.remindAt,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
    contentUpdatedAt: DateTime.fromMillisecondsSinceEpoch(r.contentUpdatedAt),
    blocks: (jsonDecode(r.blocksJson) as List)
        .map((e) => Block.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
