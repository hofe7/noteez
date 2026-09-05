import 'hybrid_relevance.dart';

class GroupSuggestion {
  const GroupSuggestion({
    required this.noteId,
    required this.groupId,
    required this.score,
    required this.reasons,
  });

  final String noteId;
  final String groupId;
  final double score;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
    'noteId': noteId,
    'score': score,
    'reasons': reasons,
  };
}

/// Suggest additions without moving notes or changing confirmed memberships.
/// Use up to three close members, so one accidental match cannot dominate a
/// large group. Ambiguous candidates stay unassigned for the user to decide.
class GroupSuggestionEngine {
  static List<GroupSuggestion> build({
    required Iterable<String> noteIds,
    required Map<String, List<String>> groups,
    required HybridRelevanceResult Function(String, String) relevance,
    bool Function(String noteId, String groupId)? isDismissed,
    bool Function(String, String)? isPairDismissed,
    double threshold = HybridRelevance.suggestionThreshold,
    double margin = 0.06,
    int limitPerGroup = 3,
  }) {
    final assigned = groups.values.expand((ids) => ids).toSet();
    final suggestions = <GroupSuggestion>[];
    for (final noteId in noteIds.toSet().toList()..sort()) {
      if (assigned.contains(noteId)) continue;
      final candidates = <GroupSuggestion>[];
      for (final group in groups.entries) {
        if (group.value.isEmpty) continue;
        final results = [
          for (final member in group.value.toSet())
            if (!(isPairDismissed?.call(noteId, member) ?? false))
              relevance(noteId, member),
        ]..sort((a, b) => b.score.compareTo(a.score));
        if (results.isEmpty) continue;
        final support = results.take(3).toList();
        final score =
            support.fold<double>(0, (s, r) => s + r.score) / support.length;
        candidates.add(
          GroupSuggestion(
            noteId: noteId,
            groupId: group.key,
            score: score,
            reasons: results.first.reasons,
          ),
        );
      }
      candidates.sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : a.groupId.compareTo(b.groupId);
      });
      if (candidates.isEmpty) continue;
      final best = candidates.first;
      if (best.score < threshold ||
          (candidates.length > 1 &&
              best.score - candidates[1].score < margin) ||
          (isDismissed?.call(noteId, best.groupId) ?? false)) {
        continue;
      }
      suggestions.add(best);
    }
    suggestions.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.noteId.compareTo(b.noteId);
    });
    final counts = <String, int>{};
    return suggestions.where((s) {
      final count = counts.update(s.groupId, (n) => n + 1, ifAbsent: () => 1);
      return count <= limitPerGroup;
    }).toList();
  }
}
