// ignore_for_file: experimental_member_use, implementation_imports
import 'dart:async';
// Quill exposes this override specifically for tests without platform plugins.
import 'package:flutter_quill/src/common/utils/quill_native_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show ChangeSource;
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/editor/note_editor.dart';
import 'package:noteez/editor/pasted_image_store.dart';
import 'package:noteez/models/sticky.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => QuillNativeProvider.instance = _TextClipboardBridge());
  tearDown(() => QuillNativeProvider.instance = null);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  test('clipboard image is durable PNG; malformed data leaves no file', () async {
    final root = await Directory.systemTemp.createTemp('noteez-pasted-image-');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = PastedImageStore(directory: root);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
    final path = await store.save(bytes);
    expect(await File(path).exists(), isTrue);
    expect(path, endsWith('.png'));
    expect(await store.save(bytes), path);
    await expectLater(
      store.save(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
    expect(await root.list().length, 1);
  });

  testWidgets(
    'image paste replaces selected text and survives block round-trip',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('noteez-image-editor-'),
      ))!;
      addTearDown(() => root.deleteSync(recursive: true));
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      );
      const pasteboard = MethodChannel('pasteboard');
      messenger.setMockMethodCallHandler(pasteboard, (_) async => bytes);
      addTearDown(() => messenger.setMockMethodCallHandler(pasteboard, null));
      final key = GlobalKey<NoteEditorState>();
      List<Block> saved = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              key: key,
              imageStore: PastedImageStore(directory: root),
              initial: [textBlock('replace me')],
              onChanged: (blocks) => saved = blocks,
            ),
          ),
        ),
      );
      final controller = key.currentState!.controller;
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 10),
        ChangeSource.local,
      );
      await tester.runAsync(() => controller.clipboardPaste());
      await tester.pumpAndSettle();
      final image = saved.whereType<ImageBlock>().single;
      expect(File(image.path).existsSync(), isTrue);
      expect(saved.map((b) => b.text).join(), isNot(contains('replace me')));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              key: UniqueKey(),
              initial: saved,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native paste replaces selection once and ignores unfocused editor',
    (tester) async {
      final key = GlobalKey<NoteEditorState>();
      final enabled = <bool>[];
      const native = MethodChannel('noteez/paste');
      messenger.setMockMethodCallHandler(native, (call) async {
        enabled.add(call.arguments as bool);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(native, null));
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': '**회의록**\n- 지시사항'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              key: key,
              initial: [textBlock('old')],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final state = key.currentState!;
      expect(
        state.controller.config.clipboardConfig!.enableExternalRichPaste,
        isFalse,
      );
      Future<void> paste() async {
        await tester.runAsync(() async {
          final done = Completer<void>();
          messenger.handlePlatformMessage(
            'noteez/paste',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('paste'),
            ),
            (_) => done.complete(),
          );
          await done.future;
        });
        await tester.pumpAndSettle();
      }

      await paste();
      expect(state.controller.document.toPlainText(), 'old\n');
      state.focusEnd();
      await tester.pumpAndSettle();
      state.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
        ChangeSource.local,
      );
      await paste();
      expect(state.controller.document.toPlainText(), '**회의록**\n- 지시사항\n');
      expect(enabled, contains(true));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(enabled.last, isFalse);
    },
  );
}

class _TextClipboardBridge extends QuillNativeBridge {
  @override
  Future<bool> isSupported(QuillNativeBridgeFeature feature) async => false;
}
