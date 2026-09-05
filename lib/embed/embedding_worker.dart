import 'dart:async';
import 'dart:isolate';

import 'package:onnxruntime/onnxruntime.dart' show OrtEnv;

import 'onnx_embedder.dart';
import 'document_embedding.dart';
import 'unigram_tokenizer.dart';

abstract interface class TextEmbedder {
  Future<List<double>> embed(String text);
  Future<void> close();
}

abstract interface class DocumentEmbedder implements TextEmbedder {
  Future<DocumentEmbedding> embedDocument(
    List<String> paragraphs,
    Map<String, List<double>> cached,
  );
}

/// One long-lived worker owns both the tokenizer and native ONNX session.
/// Only strings and vectors cross isolates; native handles never do.
class EmbeddingWorker implements DocumentEmbedder {
  EmbeddingWorker(this.modelPath, this.tokenizerPath);

  final String modelPath;
  final String tokenizerPath;
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<dynamic>> _pending = {};
  final Completer<SendPort> _ready = Completer<SendPort>();
  Future<void>? _starting;
  Isolate? _isolate;
  final Completer<void> _exited = Completer<void>();
  bool _closed = false;
  int _nextId = 0;

  Future<void> _start() async {
    _responses.listen((dynamic message) {
      if (message is SendPort) {
        _ready.complete(message);
      } else if (message is List && message.length == 3) {
        final completer = _pending.remove(message[0]);
        if (completer == null) return;
        if (message[2] != null) {
          completer.completeError(StateError(message[2] as String));
        } else {
          completer.complete(message[1]);
        }
      } else {
        // Includes an unexpected native worker exit or uncaught isolate error.
        final error = StateError('Embedding worker stopped unexpectedly.');
        if (!_ready.isCompleted) _ready.completeError(error);
        for (final completer in _pending.values) {
          completer.completeError(error);
        }
        _pending.clear();
        _closed = true;
        if (!_exited.isCompleted) _exited.complete();
        _responses.close();
      }
    });
    _isolate = await Isolate.spawn(
      _run,
      (_responses.sendPort, modelPath, tokenizerPath),
      onExit: _responses.sendPort,
      onError: _responses.sendPort,
    );
  }

  @override
  Future<List<double>> embed(String text) async =>
      ((await _request(text)) as List).cast<double>();

  @override
  Future<DocumentEmbedding> embedDocument(
    List<String> paragraphs,
    Map<String, List<double>> cached,
  ) async => DocumentEmbedding.parse(await _request((paragraphs, cached)))!;

  Future<dynamic> _request(dynamic text) async {
    if (_closed) throw StateError('Embedding worker is closed.');
    await (_starting ??= _start());
    final port = await _ready.future;
    if (_closed) throw StateError('Embedding worker is closed.');
    final id = _nextId++;
    final result = Completer<dynamic>();
    _pending[id] = result;
    port.send((id, text));
    return result.future;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final completer in _pending.values) {
      completer.completeError(StateError('Embedding worker is closed.'));
    }
    _pending.clear();
    if (_starting == null) {
      _responses.close();
      return;
    }
    try {
      await _starting;
      final port = await _ready.future;
      port.send(null);
      await _exited.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      _isolate?.kill(priority: Isolate.immediate);
    } finally {
      _responses.close();
    }
  }

  static void _run((SendPort, String, String) config) {
    final (reply, modelPath, tokenizerPath) = config;
    final requests = ReceivePort();
    OnnxEmbedder? embedder;
    UnigramTokenizer? tokenizer;
    void disposeNative() {
      embedder?.dispose();
      embedder = null;
      tokenizer = null;
      try {
        OrtEnv.instance.release();
      } catch (_) {
        // The shared library itself may have failed to load.
      }
    }

    reply.send(requests.sendPort);
    requests.listen((dynamic message) {
      if (message == null) {
        disposeNative();
        requests.close();
        return;
      }
      final (id, text) = message as (int, dynamic);
      try {
        if (embedder == null) {
          embedder = OnnxEmbedder()..init(modelPath);
          tokenizer = UnigramTokenizer()..load(tokenizerPath);
        }
        if (text is (List<String>, Map<String, List<double>>)) {
          final result = embedDocumentChunks(
            documentTokenChunks(text.$1, tokenizer!),
            text.$2,
            (ids) => embedder!.embedFromIds(ids, List.filled(ids.length, 1)),
          );
          reply.send([id, result.toJson(), null]);
          return;
        }
        final ids = tokenizer!.encode(text as String);
        final vector = embedder!.embedFromIds(
          ids,
          List<int>.filled(ids.length, 1),
        );
        reply.send([id, vector, null]);
      } catch (error) {
        disposeNative();
        reply.send([id, null, error.toString()]);
      }
    });
  }
}
