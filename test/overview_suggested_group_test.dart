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
}
