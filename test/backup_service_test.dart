import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:noteez/db/database.dart';
import 'package:noteez/backup/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory support;
  late BackupService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('noteez-backup-test-');
    documents = Directory(p.join(root.path, 'documents'));
    support = Directory(p.join(root.path, 'support'));
    await documents.create(recursive: true);
    await support.create(recursive: true);
    service = BackupService(
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      now: () => DateTime(2026, 9, 4, 12, 30),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'schema 12 backup preserves content time, welcome state and group rejection',
    () async {
      final file = File(p.join(documents.path, 'noteez.sqlite'));
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await db.initializeWelcome();
      final note = (await db.allActive()).single.copyWith(
        contentUpdatedAt: DateTime.utc(2026, 1, 2),
      );
      await db.upsert(note);
      await db.upsertNoteGroup(id: 'project', name: 'Project', position: 0);
      await db.dismissGroupSuggestion(note.id, 'project');
      await db.close();
      final zip = p.join(root.path, 'schema12.zip');
      await service.createBackup(zip);
      db = AppDatabase.forTesting(NativeDatabase(file));
      await db.resetGroupSuggestions('project');
      await db.softDelete(note.id);
      await db.close();
      await service.stageRestore(zip);
      expect(await service.applyPendingRestore(), isTrue);
      db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await db.allActive()).single.contentUpdatedAt.toUtc(),
          DateTime.utc(2026, 1, 2),
        );
        expect(
          (await db.allGroupSuggestionDismissals()).single.groupId,
          'project',
        );
        await db.softDelete(note.id);
        await db.initializeWelcome();
        expect(await db.allActive(), isEmpty);
      } finally {
        await db.close();
      }
    },
  );

  test('backs up and restores notes with portable image paths', () async {
    final originalImage = File(p.join(root.path, 'outside', 'photo.png'));
    await originalImage.parent.create(recursive: true);
    await originalImage.writeAsBytes([1, 2, 3, 4]);
    _createDatabase(
      p.join(documents.path, 'noteez.sqlite'),
      id: 'original',
      blocks: [
        {'type': 'text', 'id': 'text', 'text': '회의 메모'},
        {'type': 'image', 'id': 'image', 'path': originalImage.path},
      ],
    );

    final zip = p.join(root.path, 'portable.zip');
    final backup = await service.createBackup(zip);
    expect(backup?.noteCount, 1);
    expect(backup?.imageCount, 1);

    File(p.join(documents.path, 'noteez.sqlite')).deleteSync();
    _createDatabase(
      p.join(documents.path, 'noteez.sqlite'),
      id: 'replacement',
      blocks: [
        {'type': 'text', 'id': 'other', 'text': '교체될 메모'},
      ],
    );

    final staged = await service.stageRestore(zip);
    expect(staged.noteCount, 1);
    expect(staged.imageCount, 1);
    expect(await service.applyPendingRestore(), isTrue);
    expect(await service.applyPendingRestore(), isFalse);

    final database = sqlite3.open(
      p.join(documents.path, 'noteez.sqlite'),
      mode: OpenMode.readOnly,
    );
    try {
      final row = database
          .select('SELECT id, blocks_json FROM stickies')
          .single;
      expect(row['id'], 'original');
      final blocks = (jsonDecode(row['blocks_json'] as String) as List)
          .cast<Map<String, dynamic>>();
      final restoredPath =
          blocks.singleWhere((block) => block['type'] == 'image')['path']
              as String;
      expect(
        restoredPath,
        startsWith(p.join(support.path, 'imports', 'assets')),
      );
      expect(await File(restoredPath).readAsBytes(), [1, 2, 3, 4]);
    } finally {
      database.close();
    }
  });

  test('keeps only the configured number of automatic backups', () async {
    _createDatabase(
      p.join(documents.path, 'noteez.sqlite'),
      id: 'note',
      blocks: [
        {'type': 'text', 'id': 'text', 'text': '메모'},
      ],
    );
    service = BackupService(
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      now: () => DateTime(2026, 9, 4, 12, 30),
      maxAutomaticBackups: 2,
    );

    await service.createAutomaticBackup();
    await service.createAutomaticBackup();
    await service.createAutomaticBackup();

    final files = await Directory(p.join(support.path, 'backups'))
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.zip'))
        .toList();
    expect(files, hasLength(2));
    final history = await service.listAutomaticBackups();
    expect(history, hasLength(2));
    expect(history.first.isValid, isTrue);
    expect(history.first.noteCount, 1);
    expect(history.first.imageCount, 0);
  });

  test('rejects an arbitrary zip before staging a restore', () async {
    final invalid = File(p.join(root.path, 'invalid.zip'));
    await invalid.writeAsBytes([0, 1, 2, 3]);

    await expectLater(service.stageRestore(invalid.path), throwsA(anything));
    expect(
      Directory(
        p.join(support.path, 'backups', 'pending-restore'),
      ).existsSync(),
      isFalse,
    );
  });
}

void _createDatabase(
  String path, {
  required String id,
  required List<Map<String, dynamic>> blocks,
}) {
  final database = sqlite3.open(path);
  try {
    database.execute('''
      CREATE TABLE stickies (
        id TEXT PRIMARY KEY NOT NULL,
        blocks_json TEXT NOT NULL
      )
    ''');
    database.execute('INSERT INTO stickies (id, blocks_json) VALUES (?, ?)', [
      id,
      jsonEncode(blocks),
    ]);
    database.execute('PRAGMA user_version = 11');
  } finally {
    database.close();
  }
}
