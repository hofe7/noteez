import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/db/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  for (var version = 1; version < databaseSchemaVersion; version++) {
    test(
      'reconstructed schema $version migrates every table and keeps content',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'noteez-migration-audit-',
        );
        addTearDown(() => root.delete(recursive: true));
        final file = File('${root.path}/noteez.sqlite');
        var db = AppDatabase.forTesting(NativeDatabase(file));
        await db.initializeWelcome();
        final before = (await db.allActive()).single;
        await db.close();
        final legacy = sqlite3.open(file.path);
        try {
          final columns = {
            'content_updated_at': 12,
            'width': 11,
            'height': 11,
            'remind_at': 6,
            'open': 5,
            'pinned': 2,
          };
          for (final entry in columns.entries) {
            if (version < entry.value) {
              legacy.execute('ALTER TABLE stickies DROP COLUMN ${entry.key}');
            }
          }
          if (version < 9 && version >= 4) {
            legacy.execute('ALTER TABLE embeddings DROP COLUMN model_id');
          }
          final tables = {
            'group_suggestion_dismissals': 12,
            'app_settings': 12,
            'group_members': 10,
            'note_groups': 10,
            'import_origins': 8,
            'suggestion_dismissals': 7,
            'embeddings': 4,
            'links': 3,
          };
          for (final entry in tables.entries) {
            if (version < entry.value) {
              legacy.execute('DROP TABLE ${entry.key}');
            }
          }
          legacy.execute('PRAGMA user_version = $version');
        } finally {
          legacy.close();
        }
        db = AppDatabase.forTesting(NativeDatabase(file));
        try {
          for (final table in db.allTables) {
            await db.select(table).get();
          }
          final after = (await db.allActive()).single;
          expect(after.id, before.id);
          expect(
            after.blocks.map((b) => b.text),
            before.blocks.map((b) => b.text),
          );
          expect(after.contentUpdatedAt, after.updatedAt);
          await db.softDelete(after.id);
          await db.initializeWelcome();
          expect(await db.allActive(), isEmpty);
        } finally {
          await db.close();
        }
      },
    );
  }
}
