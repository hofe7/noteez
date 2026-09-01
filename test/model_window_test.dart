import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/models/model_catalog.dart';
import 'package:noteez/windows/model_window.dart';

void main() {
  testWidgets('shows curated model choices and privacy boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      ModelWindowApp(
        initialState: {
          'selectedId': null,
          'activeId': null,
          'activity': 'idle',
          'progress': 0.0,
          'indexed': 0,
          'indexTotal': 0,
          'models': [
            for (final model in ModelCatalog.models)
              {...model.toJson(), 'installed': false, 'selected': false},
          ],
        },
      ),
    );
    await tester.pump();

    expect(find.text('Multilingual E5 Small'), findsOneWidget);
    expect(find.text('Multilingual E5 Base'), findsOneWidget);
    expect(find.text('다운로드'), findsNWidgets(2));
    expect(find.textContaining('메모와 임베딩은 이 Mac 밖으로'), findsOneWidget);
    expect(find.text('Hugging Face에서 찾기'), findsOneWidget);
    expect(find.textContaining('저장소 코드는 실행하지 않습니다'), findsOneWidget);
  });
}
