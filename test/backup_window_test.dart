import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/windows/backup_window.dart';

void main() {
  testWidgets('shows backup history and explains safe restore', (tester) async {
    await tester.pumpWidget(
      BackupWindowApp(
        initialState: {
          'directoryPath': '/tmp/backups',
          'backups': [
            {
              'path': '/tmp/backups/latest.zip',
              'name': 'latest.zip',
              'createdAt': DateTime(2026, 9, 4, 12, 30).millisecondsSinceEpoch,
              'sizeBytes': 2 * 1024 * 1024,
              'noteCount': 42,
              'imageCount': 3,
              'isValid': true,
            },
          ],
        },
      ),
    );
    await tester.pump();

    expect(find.text('자동 백업'), findsOneWidget);
    expect(find.text('지금 백업'), findsOneWidget);
    expect(find.text('Finder에서 보기'), findsOneWidget);
    expect(find.text('최신'), findsOneWidget);
    expect(find.text('메모 42개 · 이미지 3개 · 2.0 MB'), findsOneWidget);

    await tester.tap(find.text('복원'));
    await tester.pumpAndSettle();
    expect(find.text('이 시점으로 되돌릴까요?'), findsOneWidget);
    expect(find.textContaining('현재 상태도 먼저 자동 백업'), findsOneWidget);
    expect(find.text('복원하고 재시작'), findsOneWidget);
  });

  testWidgets('renders an empty history without a dead end', (tester) async {
    await tester.pumpWidget(
      const BackupWindowApp(
        initialState: {'directoryPath': '/tmp/backups', 'backups': []},
      ),
    );
    await tester.pump();

    expect(find.text('아직 자동 백업이 없습니다.'), findsOneWidget);
    expect(find.text('지금 백업'), findsOneWidget);
  });
}
