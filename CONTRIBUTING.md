# Contributing to Noteez

작은 버그 수정, 사용성 제안, 테스트와 문서 기여를 환영합니다.
큰 기능은 구현 전에 이슈에서 사용자 문제와 동작 예시를 먼저 설명해 주세요.

## 개발 시작

macOS 앱 개발에는 Flutter **3.41.7**(CI 고정 버전), Xcode와 CocoaPods가 필요합니다.
Linux에서는 분석과 기본 테스트를 실행할 수 있지만 macOS 창·메뉴바 동작은 검증되지 않습니다.

```sh
flutter pub get
flutter run -d macos
```

모델이나 계정 없이 시작할 수 있습니다. 첫 실행에는 안내 메모 한 장만 생성됩니다.
추천 시연에는 `test/fixtures/relevance/notes.json`의 가상 메모를 사용해 주세요.
개인 메모 DB나 백업 파일을 저장소·이슈·테스트에 넣지 마세요.

## 변경 전후 확인

```sh
flutter analyze --fatal-infos
flutter test
# DB 테이블을 바꾼 경우
dart run build_runner build
# macOS 네이티브 코드, 플러그인, 창 처리 등을 바꾼 경우
flutter build macos --release
```

수정한 Dart 파일에 `dart format`을 실행하고 관련 없는 파일의 포맷 변경은 제외해 주세요.
DB 변경은 버전 업그레이드와 기존 데이터·백업 복원 테스트를 함께 추가합니다.
코드 생성 결과인 `lib/db/database.g.dart`도 커밋합니다.

로컬 모델 추론과 추천 품질 평가는 [평가 안내](docs/relevance-evaluation.md)를 참고하세요.
기본 테스트는 모델을 다운로드하지 않습니다. 가상 데이터 평가 통과는 추천 품질 보증이 아닙니다.

## 코드의 책임

- `editor/pending_save.dart`: 편집 저장 순서, 디바운스, 닫기 전 저장 완료.
- `embed/embedding_worker.dart`: 별도 isolate의 토크나이저와 ONNX 세션.
- `connection_engine.dart`: 최신 콘텐츠에 대한 인덱싱, 모델 세대 검사, 연결 추천.
- `group_suggestions.dart`: 기존 묶음에 추가할 후보 평가. 멤버십을 변경하지 않는 순수 함수.
- `main_controller.dart`: DB·창·IPC의 조율. 창의 쓰기 완료를 기다린 뒤 종료.
- `db/database.dart`: 영속 데이터, 마이그레이션, 최초 실행 상태.

추가 코드도 가능한 한 순수 로직을 UI·IPC와 분리하고, 외부 부작용을 주입 가능하게 유지하세요.

## PR에 적을 내용

1. 어떤 사용자 문제가 있었고, 어떤 행동으로 재현되는가?
2. 변경 후 행동은 무엇인가? UI 변경이면 가상 데이터 화면을 첨부한다.
3. 실행한 테스트·빌드와 아직 검증하지 못한 환경은 무엇인가?
4. 데이터 형식 변경이나 모델 동작 변경이 있는가?

처음 기여하기 좋은 범위는 접근성 레이블, 키보드 조작, 한영 혼용 추천 사례,
데이터 이동성 예외 사례, 설치 문서입니다. 평가 데이터의 정답은 실제 예측 결과를
보고 바꾸지 말고, 사람이 생각하는 묶음의 의도를 기준으로 작성해 주세요.

보안 문제는 [SECURITY.md](SECURITY.md)의 비공개 제보 절차를 따라 주세요.

## 공개 문서와 개인 메모

`README.md`, `docs/`, `CONTRIBUTING.md`, `SECURITY.md`는 저장소에 함께 공개할 문서입니다.
개인 구상·개발 일지·임시 평가 캐시는 `.local-dev/`에 둡니다. 이 폴더는 `.gitignore`로
제외되며 일반적인 `git add`에 포함되지 않습니다. `git add -f` 또는 별도 업로드는
이 제외 규칙을 우회하므로 사용하지 마세요. 제외 규칙은 이미 공개한 과거 커밋을
삭제하지 않습니다.

새 추천 정책은 `lib/automatic_clusters.dart`에서 핵심 묶음 생성과 확장을 담당합니다.
평가용 개발·검증 데이터의 주제와 문장은 서로 겹치지 않아야 하며, 검증 결과를 본 뒤
같은 검증 세트에 맞춰 임계값을 다시 조정하지 마세요.


## 공개 문서와 로컬 작업 기록

`docs/`에는 사용법, 구조, 재현 가능한 평가와 공개 검증 결과만 보관합니다.
개인 구상, 대화 기반 작업 일지, 도구 실패 기록, 설치·백업 경로와 임시 결과는
Git에서 제외된 `.local-dev/`에 보관합니다. `.local-dev/`, `.claude/`, `.omc/`를
강제로 추가하지 마세요. 문서 PR에서도 이 구분을 확인해 주세요.
