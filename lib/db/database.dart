import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/sticky.dart';

part 'database.g.dart';

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
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get open => boolean().withDefault(const Constant(true))();
  IntColumn get remindAt => integer().nullable()(); // 리마인더 시각(millis)
  TextColumn get blocksJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
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
  TextColumn get hash => text()();
  TextColumn get vec => text()(); // JSON [double,...]

  @override
  Set<Column> get primaryKey => {stickyId};
}

@DriftDatabase(tables: [Stickies, Links, Embeddings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'noteez'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(stickies, stickies.pinned);
          if (from < 3) await m.createTable(links);
          if (from < 4) await m.createTable(embeddings);
          if (from < 5) await m.addColumn(stickies, stickies.open);
          if (from < 6) await m.addColumn(stickies, stickies.remindAt);
        },
      );

  Future<List<EmbeddingRow>> allEmbeddings() => select(embeddings).get();

  Future<void> upsertEmbedding(String id, String hash, String vec) =>
      into(embeddings).insertOnConflictUpdate(
        EmbeddingsCompanion.insert(stickyId: id, hash: hash, vec: vec),
      );

  Future<void> deleteEmbedding(String id) =>
      (delete(embeddings)..where((t) => t.stickyId.equals(id))).go();

  Future<List<LinkRow>> allActiveLinks() =>
      (select(links)..where((t) => t.deletedAt.isNull())).get();

  Future<void> insertLink(String id, String a, String b, int createdAt) =>
      into(links).insert(
        LinksCompanion.insert(id: id, aId: a, bId: b, createdAt: createdAt),
      );

  /// 삭제 안 된 스티커 전부.
  Future<List<Sticky>> allActive() async {
    final rows =
        await (select(stickies)..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsert(Sticky s) {
    return into(stickies).insertOnConflictUpdate(
      StickiesCompanion.insert(
        id: s.id,
        colorIndex: s.colorIndex,
        x: s.x,
        y: s.y,
        collapsed: Value(s.collapsed),
        pinned: Value(s.pinned),
        open: Value(s.open),
        remindAt: Value(s.remindAt),
        blocksJson: jsonEncode(s.blocks.map((b) => b.toJson()).toList()),
        createdAt: s.createdAt.millisecondsSinceEpoch,
        updatedAt: s.updatedAt.millisecondsSinceEpoch,
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

  static Sticky _toModel(StickyRow r) => Sticky(
        id: r.id,
        colorIndex: r.colorIndex,
        x: r.x,
        y: r.y,
        collapsed: r.collapsed,
        pinned: r.pinned,
        open: r.open,
        remindAt: r.remindAt,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
        blocks: (jsonDecode(r.blocksJson) as List)
            .map((e) => Block.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
