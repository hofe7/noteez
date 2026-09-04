import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const _backupFormat = 'noteez-backup';
const _backupFormatVersion = 1;
const _databaseSchemaVersion = 11;
const _portableAssetPrefix = 'noteez-backup://assets/';
const _zipTypes = <XTypeGroup>[
  XTypeGroup(label: 'Noteez backup', extensions: ['zip']),
];

class BackupResult {
  const BackupResult({
    required this.path,
    required this.noteCount,
    required this.imageCount,
  });

  final String path;
  final int noteCount;
  final int imageCount;
}

class RestoreResult {
  const RestoreResult({required this.noteCount, required this.imageCount});

  final int noteCount;
  final int imageCount;
}

/// Consistent, portable backups for the database and image blocks.
/// Downloaded AI models are deliberately excluded because they are large and
/// can be installed again from the model manager.
class BackupService {
  BackupService({
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? supportDirectory,
    DateTime Function()? now,
    this.maxAutomaticBackups = 10,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _now;
  final int maxAutomaticBackups;

  Future<BackupResult?> pickAndCreateBackup() async {
    final location = await getSaveLocation(
      suggestedName: '${_backupName(_now())}.zip',
      acceptedTypeGroups: _zipTypes,
      confirmButtonText: '백업 저장',
    );
    if (location == null) return null;
    return createBackup(location.path);
  }

  Future<RestoreResult?> pickAndStageRestore() async {
    final file = await openFile(
      acceptedTypeGroups: _zipTypes,
      confirmButtonText: '복원',
    );
    if (file == null) return null;
    return stageRestore(file.path);
  }

  /// Creates a rotating backup in the app support directory. A missing DB is
  /// normal on the very first launch and simply produces no backup.
  Future<BackupResult?> createAutomaticBackup() async {
    final support = await _supportDirectory();
    final root = Directory(p.join(support.path, 'backups'));
    await root.create(recursive: true);
    final result = await createBackup(
      await _uniqueBackupPath(root, _backupName(_now())),
    );
    await _rotateAutomaticBackups(root);
    return result;
  }

  Future<BackupResult?> createBackup(String destinationPath) async {
    final documents = await _documentsDirectory();
    final sourceFile = File(p.join(documents.path, 'noteez.sqlite'));
    if (!await sourceFile.exists()) return null;

    final support = await _supportDirectory();
    final workRoot = Directory(p.join(support.path, 'backups', '.work'));
    await workRoot.create(recursive: true);
    final staging = await workRoot.createTemp('create-');
    try {
      final databaseDir = Directory(p.join(staging.path, 'database'));
      await databaseDir.create(recursive: true);
      final snapshot = File(p.join(databaseDir.path, 'noteez.sqlite'));
      await _snapshotDatabase(sourceFile.path, snapshot.path);

      final portable = await _makeSnapshotPortable(snapshot, staging);
      final manifest = {
        'format': _backupFormat,
        'formatVersion': _backupFormatVersion,
        'createdAt': _now().toUtc().toIso8601String(),
        'databaseSchemaVersion': _databaseSchemaVersion,
        'noteCount': portable.noteCount,
        'imageCount': portable.imageCount,
      };
      await File(
        p.join(staging.path, 'manifest.json'),
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));

      final destination = File(destinationPath);
      await destination.parent.create(recursive: true);
      final partial = File('${destination.path}.partial');
      if (await partial.exists()) await partial.delete();
      await ZipFileEncoder().zipDirectory(
        staging,
        filename: partial.path,
        followLinks: false,
      );
      if (await destination.exists()) await destination.delete();
      await partial.rename(destination.path);
      return BackupResult(
        path: destination.path,
        noteCount: portable.noteCount,
        imageCount: portable.imageCount,
      );
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Validates and stages a restore. The live database is never replaced while
  /// Noteez is running; [applyPendingRestore] performs the swap on next launch.
  Future<RestoreResult> stageRestore(String zipPath) async {
    final inputFile = File(zipPath);
    if (!await inputFile.exists()) {
      throw const FormatException('백업 파일을 찾을 수 없습니다.');
    }

    final support = await _supportDirectory();
    final backupRoot = Directory(p.join(support.path, 'backups'));
    await backupRoot.create(recursive: true);
    final extracted = await backupRoot.createTemp('restore-');
    try {
      // The selected file can itself be an old automatic backup. Keep a local
      // copy before rotation so the pre-restore backup cannot remove it.
      final selectedCopy = await inputFile.copy(
        p.join(extracted.path, 'selected.zip'),
      );
      await createAutomaticBackup();
      final contents = Directory(p.join(extracted.path, 'contents'));
      await contents.create();
      await _extractZipSafely(selectedCopy.path, contents.path);
      final snapshotSource = File(
        p.join(contents.path, 'database', 'noteez.sqlite'),
      );
      final actualManifest = File(p.join(contents.path, 'manifest.json'));
      if (!await actualManifest.exists() || !await snapshotSource.exists()) {
        throw const FormatException('올바른 Noteez 백업이 아닙니다.');
      }
      final manifest = jsonDecode(await actualManifest.readAsString());
      if (manifest is! Map<String, dynamic> ||
          manifest['format'] != _backupFormat ||
          manifest['formatVersion'] != _backupFormatVersion) {
        throw const FormatException('지원하지 않는 Noteez 백업 형식입니다.');
      }
      final schema = manifest['databaseSchemaVersion'];
      if (schema is! int || schema > _databaseSchemaVersion) {
        throw const FormatException('더 최신 버전의 Noteez에서 만든 백업입니다.');
      }
      _validateDatabase(snapshotSource.path);

      final pendingNew = await backupRoot.createTemp('pending-');
      var keepPending = false;
      try {
        final pendingDatabase = File(p.join(pendingNew.path, 'noteez.sqlite'));
        await snapshotSource.copy(pendingDatabase.path);
        final imageCount = await _prepareRestoredAssets(
          pendingDatabase,
          contents,
          pendingNew,
          support,
        );
        final noteCount = _noteCount(pendingDatabase.path);
        await File(p.join(pendingNew.path, 'ready.json')).writeAsString(
          jsonEncode({'noteCount': noteCount, 'imageCount': imageCount}),
        );

        final pending = Directory(p.join(backupRoot.path, 'pending-restore'));
        if (await pending.exists()) await pending.delete(recursive: true);
        await pendingNew.rename(pending.path);
        keepPending = true;
        return RestoreResult(noteCount: noteCount, imageCount: imageCount);
      } finally {
        if (!keepPending && await pendingNew.exists()) {
          await pendingNew.delete(recursive: true);
        }
      }
    } finally {
      if (await extracted.exists()) await extracted.delete(recursive: true);
    }
  }

  /// Applies a previously validated restore before Drift opens the database.
  Future<bool> applyPendingRestore() async {
    final support = await _supportDirectory();
    final pending = Directory(
      p.join(support.path, 'backups', 'pending-restore'),
    );
    final ready = File(p.join(pending.path, 'ready.json'));
    final stagedDatabase = File(p.join(pending.path, 'noteez.sqlite'));
    if (!await ready.exists() || !await stagedDatabase.exists()) return false;
    _validateDatabase(stagedDatabase.path);

    final stagedAssets = Directory(p.join(pending.path, 'assets'));
    final targetAssets = Directory(p.join(support.path, 'imports', 'assets'));
    if (await stagedAssets.exists()) {
      await targetAssets.create(recursive: true);
      await for (final entity in stagedAssets.list()) {
        if (entity is File) {
          final target = File(
            p.join(targetAssets.path, p.basename(entity.path)),
          );
          if (!await target.exists()) await entity.copy(target.path);
        }
      }
    }

    final documents = await _documentsDirectory();
    await documents.create(recursive: true);
    final live = File(p.join(documents.path, 'noteez.sqlite'));
    final replacement = File(p.join(documents.path, 'noteez.restore-new'));
    final previous = File(p.join(documents.path, 'noteez.restore-old'));
    if (await replacement.exists()) await replacement.delete();
    if (await previous.exists()) await previous.delete();
    await stagedDatabase.copy(replacement.path);

    var movedLive = false;
    try {
      if (await live.exists()) {
        await live.rename(previous.path);
        movedLive = true;
      }
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('${live.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await replacement.rename(live.path);
      if (await previous.exists()) await previous.delete();
      await pending.delete(recursive: true);
      return true;
    } catch (_) {
      if (await replacement.exists()) await replacement.delete();
      if (movedLive && !await live.exists() && await previous.exists()) {
        await previous.rename(live.path);
      }
      rethrow;
    }
  }

  Future<({int noteCount, int imageCount})> _makeSnapshotPortable(
    File snapshot,
    Directory staging,
  ) async {
    final assets = Directory(p.join(staging.path, 'assets'));
    final database = sqlite3.open(snapshot.path);
    var imageCount = 0;
    try {
      final rows = database.select('SELECT rowid, blocks_json FROM stickies');
      for (final row in rows) {
        final decoded = jsonDecode(row['blocks_json'] as String);
        if (decoded is! List) continue;
        var changed = false;
        for (final value in decoded) {
          if (value is! Map || value['type'] != 'image') continue;
          final sourcePath = value['path'];
          if (sourcePath is! String) continue;
          final source = File(sourcePath);
          if (!await source.exists()) continue;
          final digest = await sha256.bind(source.openRead()).first;
          final extension = _safeExtension(source.path);
          final name = '$digest$extension';
          await assets.create(recursive: true);
          final target = File(p.join(assets.path, name));
          if (!await target.exists()) await source.copy(target.path);
          value['path'] = '$_portableAssetPrefix$name';
          changed = true;
          imageCount++;
        }
        if (changed) {
          database.execute(
            'UPDATE stickies SET blocks_json = ? WHERE rowid = ?',
            [jsonEncode(decoded), row['rowid']],
          );
        }
      }
      return (
        noteCount: _noteCountFromDatabase(database),
        imageCount: imageCount,
      );
    } finally {
      database.close();
    }
  }

  Future<int> _prepareRestoredAssets(
    File databaseFile,
    Directory extracted,
    Directory pending,
    Directory support,
  ) async {
    final database = sqlite3.open(databaseFile.path);
    var imageCount = 0;
    try {
      final rows = database.select('SELECT rowid, blocks_json FROM stickies');
      for (final row in rows) {
        final decoded = jsonDecode(row['blocks_json'] as String);
        if (decoded is! List) continue;
        var changed = false;
        for (final value in decoded) {
          if (value is! Map || value['type'] != 'image') continue;
          final path = value['path'];
          if (path is! String || !path.startsWith(_portableAssetPrefix)) {
            continue;
          }
          final name = path.substring(_portableAssetPrefix.length);
          if (name != p.basename(name) || name.isEmpty) {
            throw const FormatException('백업의 이미지 경로가 올바르지 않습니다.');
          }
          final source = File(p.join(extracted.path, 'assets', name));
          if (!await source.exists()) {
            throw const FormatException('백업에 필요한 이미지가 없습니다.');
          }
          final expectedDigest = p.basenameWithoutExtension(name);
          final actualDigest = await sha256.bind(source.openRead()).first;
          if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedDigest) ||
              actualDigest.toString() != expectedDigest) {
            throw const FormatException('백업 이미지 검증에 실패했습니다.');
          }
          final pendingAssets = Directory(p.join(pending.path, 'assets'));
          await pendingAssets.create(recursive: true);
          final staged = File(p.join(pendingAssets.path, name));
          if (!await staged.exists()) await source.copy(staged.path);
          value['path'] = p.join(support.path, 'imports', 'assets', name);
          changed = true;
          imageCount++;
        }
        if (changed) {
          database.execute(
            'UPDATE stickies SET blocks_json = ? WHERE rowid = ?',
            [jsonEncode(decoded), row['rowid']],
          );
        }
      }
      return imageCount;
    } finally {
      database.close();
    }
  }

  Future<void> _rotateAutomaticBackups(Directory root) async {
    if (maxAutomaticBackups < 1) return;
    final files = await root
        .list()
        .where((entity) => entity is File && p.extension(entity.path) == '.zip')
        .cast<File>()
        .toList();
    files.sort((a, b) {
      final modified = b.lastModifiedSync().compareTo(a.lastModifiedSync());
      return modified != 0 ? modified : b.path.compareTo(a.path);
    });
    for (final old in files.skip(maxAutomaticBackups)) {
      await old.delete();
    }
  }

  Future<String> _uniqueBackupPath(Directory root, String baseName) async {
    var candidate = File(p.join(root.path, '$baseName.zip'));
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(root.path, '$baseName ($suffix).zip'));
      suffix++;
    }
    return candidate.path;
  }
}

Future<void> _snapshotDatabase(
  String sourcePath,
  String destinationPath,
) async {
  final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
  final destination = sqlite3.open(destinationPath);
  try {
    await source.backup(destination).drain<void>();
  } finally {
    destination.close();
    source.close();
  }
}

void _validateDatabase(String path) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final result = database.select('PRAGMA quick_check').single.values.first;
    if (result != 'ok') {
      throw const FormatException('백업 데이터베이스가 손상되었습니다.');
    }
    final tables = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'])
        .toSet();
    if (!tables.contains('stickies')) {
      throw const FormatException('Noteez 데이터베이스가 아닙니다.');
    }
    final schemaVersion =
        database.select('PRAGMA user_version').single.values.first as int;
    if (schemaVersion > _databaseSchemaVersion) {
      throw const FormatException('더 최신 버전의 Noteez 데이터베이스입니다.');
    }
  } finally {
    database.close();
  }
}

int _noteCount(String path) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return _noteCountFromDatabase(database);
  } finally {
    database.close();
  }
}

int _noteCountFromDatabase(Database database) =>
    database.select('SELECT COUNT(*) AS count FROM stickies').single['count']
        as int;

Future<void> _extractZipSafely(String zipPath, String outputPath) async {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input, verify: true);
    var totalBytes = 0;
    for (final entry in archive) {
      final name = entry.name.replaceAll('\\', '/');
      final normalized = p.posix.normalize(name);
      if (p.posix.isAbsolute(normalized) ||
          normalized == '..' ||
          normalized.startsWith('../')) {
        throw const FormatException('안전하지 않은 ZIP 경로입니다.');
      }
      if (entry.isSymbolicLink) {
        throw const FormatException('심볼릭 링크가 포함된 ZIP은 복원할 수 없습니다.');
      }
      if (entry.isFile) totalBytes += entry.size;
    }
    if (archive.length > 20000 || totalBytes > 2 * 1024 * 1024 * 1024) {
      throw const FormatException('백업 ZIP이 너무 큽니다.');
    }
    await extractArchiveToDisk(archive, outputPath);
  } finally {
    await input.close();
  }
}

String _backupName(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Noteez Backup ${dateTime.year}-${two(dateTime.month)}-'
      '${two(dateTime.day)} ${two(dateTime.hour)}${two(dateTime.minute)}'
      '${two(dateTime.second)}';
}

String _safeExtension(String path) {
  final extension = p.extension(path).toLowerCase();
  return extension.length <= 10 && RegExp(r'^\.[a-z0-9]+$').hasMatch(extension)
      ? extension
      : '';
}
