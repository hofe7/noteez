import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persist clipboard bytes before an image path enters the document.
class PastedImageStore {
  PastedImageStore({this.directory});
  final Directory? directory;
  Future<String> save(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw const FormatException('이미지는 25MB 이하여야 합니다.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    late Uint8List png;
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 16000000) {
          throw const FormatException('이미지 해상도가 너무 큽니다.');
        }
        final codec = await descriptor.instantiateCodec();
        try {
          final frame = await codec.getNextFrame();
          try {
            final data = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data == null) throw const FormatException('이미지를 변환하지 못했습니다.');
            png = data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
    final root =
        directory ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'imports',
            'assets',
          ),
        );
    await root.create(recursive: true);
    final target = File(
      p.join(root.path, 'clipboard-${sha256.convert(png)}.png'),
    );
    final staging = File('${target.path}.${const Uuid().v4()}.tmp');
    try {
      await staging.writeAsBytes(png, flush: true);
      await staging.rename(target.path);
      return target.path;
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }
}
