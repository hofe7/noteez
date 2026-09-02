import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/windows/graph_window.dart';

void main() {
  testWidgets('overview renders suggested groups separately', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic> note(String id, String label, int color) => {
      'id': id,
      'label': label,
      'color': color,
      'open': true,
      'updatedAt': now,
      'createdAt': now,
    };

    await tester.pumpWidget(
      OverviewWindowApp(
        notes: [
          note('a', 'Redis 캐시 개선', 0),
          note('b', '세션 저장소 검토', 1),
          note('c', '장보기', 2),
        ],
        edges: const [],
        suggestedGroups: const [
          {
            'ids': ['a', 'b'],
            'score': 0.9,
          },
        ],
        notice: '가져오기 완료 · 새 메모 3개 · 연결 복원 1개',
      ),
    );
    await tester.pump();

    expect(find.text('Redis 캐시 개선 관련'), findsOneWidget);
    expect(find.text('추천'), findsWidgets);
    expect(find.text('세션 저장소 검토'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
    expect(find.textContaining('가져오기 완료'), findsOneWidget);
    expect(find.text('그 외'), findsOneWidget);
    expect(find.text('장보기'), findsOneWidget);
  });

  testWidgets('overview explains missing AI model without hiding notes', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      OverviewWindowApp(
        notes: [
          {
            'id': 'a',
            'label': '일반 검색 가능한 메모',
            'color': 0,
            'open': true,
            'updatedAt': now,
            'createdAt': now,
          },
        ],
        edges: const [],
        suggestedGroups: const [],
        modelReady: false,
      ),
    );
    await tester.pump();

    expect(find.textContaining('AI 모델을 받은 뒤'), findsOneWidget);
    expect(find.text('모델 받기'), findsOneWidget);
    expect(find.text('일반 검색 가능한 메모'), findsOneWidget);
  });

  testWidgets('manual groups take precedence over inferred groups', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic> note(String id, String label) => {
      'id': id,
      'label': label,
      'color': 0,
      'open': true,
      'updatedAt': now,
      'createdAt': now,
    };

    await tester.pumpWidget(
      OverviewWindowApp(
        notes: [note('a', 'Alpha'), note('b', 'Beta'), note('c', 'Other')],
        edges: const [
          {'a': 'a', 'b': 'b'},
        ],
        suggestedGroups: const [
          {
            'ids': ['a', 'b'],
            'score': 0.9,
          },
        ],
        groups: const [
          {
            'id': 'group',
            'name': '출시 준비',
            'position': 0,
            'collapsed': false,
            'memberIds': ['a', 'b'],
          },
        ],
      ),
    );
    await tester.pump();

    expect(find.text('출시 준비'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha 관련'), findsNothing);
    expect(find.text('연결 · Alpha'), findsNothing);
    expect(find.text('Other'), findsOneWidget);

    await tester.tap(find.text('선택'));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('묶음 만들기'), findsOneWidget);
  });
}
