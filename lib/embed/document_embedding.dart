import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'unigram_tokenizer.dart';

/// Versioned, per-document cache. Keys describe exact model input token IDs;
/// the enclosing database row supplies the model identity.
class DocumentEmbedding {
  DocumentEmbedding(this.vector, this.chunks);
  final List<double> vector;
  final Map<String, List<double>> chunks;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'vector': vector,
    'chunks': chunks,
  };

  static DocumentEmbedding? parse(dynamic value) {
    if (value is! Map || value['version'] != 1) return null;
    List<double> read(dynamic values) {
      final v = (values as List).map((v) => (v as num).toDouble()).toList();
      if (v.isEmpty || v.any((x) => !x.isFinite)) {
        throw const FormatException('Invalid embedding');
      }
      return v;
    }

    try {
      final vector = read(value['vector']);
      final chunks = (value['chunks'] as Map).map(
        (k, v) => MapEntry(k as String, read(v)),
      );
      if (chunks.isEmpty ||
          chunks.values.any((v) => v.length != vector.length)) {
        return null;
      }
      return DocumentEmbedding(vector, chunks);
    } catch (_) {
      return null;
    }
  }
}

/// Short documents keep their original input exactly. Long documents preserve
/// paragraph boundaries; oversized paragraphs are split into token windows.
List<List<int>> documentTokenChunks(
  List<String> paragraphs,
  UnigramTokenizer tokenizer,
) {
  final full = paragraphs.join(' ').trim();
  final ids = tokenizer.encode('passage: $full', maxTokens: 1 << 30);
  if (ids.length <= 512) return [ids];
  final prefix = tokenizer.encode('passage: ');
  final prefixIds = prefix.sublist(1, prefix.length - 1);
  final capacity = 510 - prefixIds.length;
  final chunks = <List<int>>[];
  for (final paragraph in paragraphs.expand((p) => p.split(RegExp(r'\r?\n')))) {
    if (paragraph.trim().isEmpty) continue;
    final encoded = tokenizer.encode(
      'passage: ${paragraph.trim()}',
      maxTokens: 1 << 30,
    );
    if (encoded.length <= 512) {
      chunks.add(encoded);
      continue;
    }
    final body = tokenizer.encode(paragraph.trim(), maxTokens: 1 << 30);
    final pieces = body.sublist(1, body.length - 1);
    for (var start = 0; start < pieces.length; start += capacity) {
      chunks.add([
        UnigramTokenizer.bos,
        ...prefixIds,
        ...pieces.sublist(start, min(start + capacity, pieces.length)),
        UnigramTokenizer.eos,
      ]);
    }
  }
  return chunks;
}

DocumentEmbedding embedDocumentChunks(
  List<List<int>> inputs,
  Map<String, List<double>> cached,
  List<double> Function(List<int>) infer,
) {
  final chunks = <String, List<double>>{};
  List<double>? sum;
  for (final ids in inputs) {
    final key = sha256.convert(utf8.encode(ids.join(','))).toString();
    final vector = chunks[key] ?? cached[key] ?? infer(ids);
    chunks[key] = vector;
    sum ??= List.filled(vector.length, 0.0);
    // Weight by input length so tiny paragraphs do not dominate grouping.
    for (var i = 0; i < sum.length; i++) {
      sum[i] += vector[i] * (ids.length - 2);
    }
  }
  if (inputs.length == 1) {
    return DocumentEmbedding(chunks.values.single, chunks);
  }
  final vector = sum!;
  final norm = sqrt(vector.fold<double>(0, (s, x) => s + x * x));
  if (norm > 0) {
    for (var i = 0; i < vector.length; i++) {
      vector[i] /= norm;
    }
  }
  return DocumentEmbedding(vector, chunks);
}
