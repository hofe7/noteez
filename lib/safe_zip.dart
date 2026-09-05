import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Shared boundary for imported archives. Validate before extracting any entry.
Future<void> extractZipSafely(String zipPath, String outputPath) async {
  final input = InputFileStream(zipPath);
  Archive? archive;
  try {
    archive = ZipDecoder().decodeStream(input, verify: true);
    var total = 0;
    final paths = <String>{};
    for (final entry in archive) {
      final path = p.posix.normalize(entry.name.replaceAll('\\', '/'));
      if (p.posix.isAbsolute(path) ||
          path == '..' ||
          path.startsWith('../') ||
          path.contains('\x00') ||
          entry.isSymbolicLink ||
          !paths.add(path)) {
        throw const FormatException('안전하지 않은 ZIP 경로입니다.');
      }
      if (entry.isFile) total += entry.size;
      if (archive.length > 20000 || total > 2 * 1024 * 1024 * 1024) {
        throw const FormatException('ZIP이 너무 큽니다.');
      }
    }
    await extractArchiveToDisk(archive, outputPath);
  } finally {
    await archive?.clear();
    await input.close();
  }
}
