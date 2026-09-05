import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'development and validation fixtures have disjoint topics and documents',
    () {
      List<Map<String, dynamic>> read(String name) =>
          (jsonDecode(
                    File(
                      'test/fixtures/relevance/$name.json',
                    ).readAsStringSync(),
                  )['notes']
                  as List)
              .cast<Map<String, dynamic>>();
      final development = read('notes');
      final validation = read('validation');
      expect(development, hasLength(100));
      expect(validation, hasLength(60));
      for (final field in ['id', 'topic', 'text']) {
        final a = development.map((row) => row[field]).toSet();
        final b = validation.map((row) => row[field]).toSet();
        expect(
          a.intersection(b),
          isEmpty,
          reason: '$field leaked across splits',
        );
      }
      for (final rows in [development, validation]) {
        expect(rows.map((row) => row['id']).toSet().length, rows.length);
        final topics = rows.map((row) => row['topic']).toSet();
        for (final topic in topics) {
          final group = rows.where((row) => row['topic'] == topic);
          expect(group.where((row) => row['role'] == 'anchor'), hasLength(2));
          expect(group.where((row) => row['role'] == 'candidate'), isNotEmpty);
        }
      }
    },
  );
}
