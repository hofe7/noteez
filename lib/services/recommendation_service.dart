import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import '../connection_engine.dart';
import '../models/sticky.dart';

String recommendationPair(String a, String b) =>
    jsonEncode(a.compareTo(b) < 0 ? [a, b] : [b, a]);

class RecommendationInput {
  const RecommendationInput({
    required this.notes,
    required this.vectors,
    required this.modelId,
    this.groups = const {},
    this.links = const {},
    this.dismissedPairs = const {},
    this.dismissedAdditions = const {},
  });
  final List<Sticky> notes;
  final Map<String, List<double>> vectors;
  final String? modelId;
  final Map<String, List<String>> groups;
  final Set<String> links, dismissedPairs, dismissedAdditions;
}

/// Pure snapshot computation. No DB, windows, filesystem or model inference.
Map<String, dynamic> calculateRecommendations(RecommendationInput input) {
  final engine = ConnectionEngine.forRecommendations(
    input.modelId,
    input.vectors,
  );
  bool dismissed(String a, String b) =>
      input.dismissedPairs.contains(recommendationPair(a, b));
  final memberships = {
    for (final group in input.groups.entries)
      for (final id in group.value) id: group.key,
  };
  final additions = engine.groupSuggestions(
    input.notes,
    input.groups,
    isDismissed: (id, group) =>
        input.dismissedAdditions.contains(jsonEncode([id, group])),
    isPairDismissed: dismissed,
  );
  return {
    'additions': {
      for (final group in input.groups.keys)
        group: [
          for (final addition in additions)
            if (addition.groupId == group) addition.toJson(),
        ],
    },
    'suggestedGroups': [
      for (final cluster in engine.suggestedClusters(
        input.notes,
        exclude: memberships.keys.toSet(),
        isDismissed: dismissed,
      ))
        {
          'ids': cluster.ids,
          'score': cluster.score,
          'reasons': cluster.reasons,
          if (cluster.title != null) 'title': cluster.title,
        },
    ],
    'referenceSuggestions': engine.referenceSuggestions(
      input.notes,
      isLinked: (a, b) => input.links.contains(recommendationPair(a, b)),
      isDismissed: dismissed,
      memberships: memberships,
    ),
  };
}

void _recommendationEntry((SendPort, RecommendationInput) message) {
  Isolate.exit(message.$1, calculateRecommendations(message.$2));
}

/// One cancellable computation at a time. The spawned isolate owns all large
/// caches; both normal completion and shutdown release them.
class RecommendationWorker {
  Isolate? _isolate;
  ReceivePort? _port;
  Completer<Map<String, dynamic>>? _pending;
  bool _closed = false;
  Future<Map<String, dynamic>> run(RecommendationInput input) async {
    if (_closed || _pending != null) {
      throw StateError('Recommendation worker unavailable');
    }
    final done = Completer<Map<String, dynamic>>();
    _pending = done;
    // A close can arrive while spawn is awaiting its handle. Attach an error
    // listener immediately; the caller still receives the original failure.
    unawaited(
      done.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    final port = ReceivePort();
    _port = port;
    port.listen((message) {
      if (done.isCompleted) return;
      if (message is Map) {
        done.complete(Map<String, dynamic>.from(message));
      } else {
        done.completeError(
          StateError('Recommendation worker exited: $message'),
        );
      }
    });
    try {
      final spawned = await Isolate.spawn(
        _recommendationEntry,
        (port.sendPort, input),
        onError: port.sendPort,
        onExit: port.sendPort,
        errorsAreFatal: true,
      );
      _isolate = spawned;
      if (_closed) spawned.kill(priority: Isolate.immediate);
      return await done.future;
    } finally {
      port.close();
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _port = null;
      _pending = null;
    }
  }

  void close() {
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _port?.close();
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Recommendation worker closed'));
    }
  }
}

/// Debounce bursts, retain only the latest pending snapshot and discard stale
/// results. Confirmed notes/groups can be rendered while this is busy.
class RecommendationService {
  RecommendationService({
    required this.onChanged,
    Future<Map<String, dynamic>> Function(RecommendationInput)? compute,
    this.debounce = const Duration(milliseconds: 180),
  }) : _computeOverride = compute;
  final void Function() onChanged;
  final Duration debounce;
  final Future<Map<String, dynamic>> Function(RecommendationInput)?
  _computeOverride;
  final _worker = RecommendationWorker();
  Timer? _timer;
  String? _signature;
  RecommendationInput Function()? _next;
  Map<String, dynamic>? result;
  String? error;
  bool _running = false, _closed = false;
  int _generation = 0;
  bool get busy => _running || _next != null;

  void update(String signature, RecommendationInput Function() snapshot) {
    if (_closed || _signature == signature) return;
    _signature = signature;
    _generation++;
    result = null; // Obsolete suggestions must not remain actionable.
    error = null;
    _next = snapshot;
    _timer?.cancel();
    _timer = Timer(debounce, _start);
  }

  void retry() {
    _signature = null;
  }

  Future<void> _start() async {
    if (_closed || _running || _next == null) return;
    final snapshot = _next!;
    _next = null;
    _running = true;
    final generation = _generation;
    try {
      final value = await (_computeOverride ?? _worker.run)(snapshot());
      if (!_closed && generation == _generation) result = value;
    } catch (_) {
      if (!_closed && generation == _generation) error = '추천을 계산하지 못했어요.';
    } finally {
      _running = false;
      if (!_closed) {
        onChanged();
        if (_next != null) unawaited(_start());
      }
    }
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _next = null;
    _worker.close();
  }
}
