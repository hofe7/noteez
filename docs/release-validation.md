# Release validation — 0.0.1 build 9

This page describes the checks and known limits of the initial public beta. It is
not a guarantee of correctness or a substitute for testing on supported hardware.

## Automated checks

- 242 tests passed; four tests requiring opt-in environments were excluded.
- Static analysis completed without issues, and the macOS release build succeeded.
- Tests cover persistence failures, database migrations, atomic imports, backup
  validation, reminder retries, conflicting undo operations, editor data, and
  asynchronous recommendation updates.
- The DMG passed image verification and its bundled app passed strict, deep
  ad-hoc signature verification. This is not Apple Developer ID signing or notarization.
- The executable and App.framework contain arm64 and x86_64 architectures.

```sh
flutter analyze
flutter test
flutter build macos --release
```

## Recommendation performance

The benchmark uses fictional notes across 20 topics and synthetic cached vectors
with 384 dimensions. It runs in the Flutter test engine on Apple Silicon. It
excludes ONNX inference and file reads, and does not measure release UI frame rate
or real-user response time. These are single-run measurements.

| Notes | Reference suggestions | Suggested groups |
| --- | ---: | ---: |
| 500 | 345 ms | 60 ms |
| 1,000 | 1,438 ms | 129 ms |

End-to-end worker computation took 730 ms for 500 notes and 2,666 ms for 1,000.
During the 1,000-note worker run, a 5 ms timer on the main isolate fired 532 times,
with a maximum observed interval of 8 ms. This checks for long synchronous
blocking; it does not establish frame rendering performance.

Recommendation work runs in a separate isolate, coalesces changes, rejects stale
results, and limits caches. Pair comparison remains O(n²), so these measurements
do not establish performance for tens of thousands of notes.

```sh
NOTEEZ_LIBRARY_BENCHMARK=1 flutter test --no-pub test/library_benchmark_test.dart
```

The Small model development, work, and holdout evaluations retained the same
predicted groups and recommendation results using the same fixtures and verified
cached vectors. See [recommendation evaluation](relevance-evaluation.md) for the
method, datasets, and remaining false-grouping cases.

## Native behavior and remaining limits

Apple Silicon installation and startup, database integrity, and preservation of
database table row counts were checked. Detailed hardware testing is incomplete
for Intel Macs, the minimum supported OS, Korean IME composition, native text and
image paste, edited-note restoration after restart, and reminders after sleep.
Widget tests with mock native channels do not replace these checks.

- Reminder delivery is best effort, not exactly once. The app retries failures,
  but a failure after delivery can cause a duplicate. It does not schedule OS
  notifications while fully quit; overdue reminders are processed on next launch.
- External formatted paste is treated as plain text. Images are saved as static
  PNG files; animated images retain only the first frame.
- Markdown database imports are atomic per parsed batch. Preliminary image copies
  are outside the database transaction. Backup coordination is within one process.
- Some controller and native UI paths have limited automated coverage. Accessibility,
  long sessions, and large real-world libraries need further testing.
- UI translation, real-time sync, and periodic timed backups are not implemented.

## Published artifact

Version: **0.0.1 build 9**. DMG size: **41,690,598 bytes**.

```text
8f02741f11e1213aa6bf9ceb54275ac2ae5c3cf81349de49a1a82d06aa3f569e  Noteez-0.0.1.dmg
```

Download and installation instructions are in the
[release notes](https://github.com/hofe7/noteez/releases/tag/v0.0.1).
