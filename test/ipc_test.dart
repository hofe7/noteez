import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/ipc.dart';

void main() {
  group('ConnectionResult.parse', () {
    test('null / 비문자열 → empty', () {
      expect(ConnectionResult.parse(null).links, isEmpty);
      expect(ConnectionResult.parse(null).suggestion, isNull);
      expect(ConnectionResult.parse(42).links, isEmpty);
    });

    test('links + suggestion 파싱', () {
      final raw = jsonEncode({
        'links': [
          {'id': 'a', 'preview': '첫 메모'},
          {'id': 'b', 'preview': '둘째'},
        ],
        'suggestion': {'id': 'c', 'preview': '제안', 'full': '제안 전문', 'score': 0.9},
      });
      final r = ConnectionResult.parse(raw);
      expect(r.links.length, 2);
      expect(r.links.first['id'], 'a');
      expect(r.suggestion!['id'], 'c');
      expect(r.suggestion!['score'], 0.9);
    });

    test('suggestion 없음(null)', () {
      final raw = jsonEncode({'links': <Map<String, dynamic>>[], 'suggestion': null});
      final r = ConnectionResult.parse(raw);
      expect(r.links, isEmpty);
      expect(r.suggestion, isNull);
    });
  });
}
