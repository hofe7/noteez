import 'dart:convert';

class GroupChange {
  const GroupChange({required this.undoToken, this.groupId});
  final String undoToken;
  final String? groupId;
  String encode() => jsonEncode({'undoToken': undoToken, 'groupId': groupId});
  factory GroupChange.decode(Object? value) {
    final data = jsonDecode(value as String) as Map<String, dynamic>;
    return GroupChange(
      undoToken: data['undoToken'] as String,
      groupId: data['groupId'] as String?,
    );
  }
}

class GroupChangeConflict implements Exception {
  const GroupChangeConflict();
  @override
  String toString() => '다른 변경이 있어 실행 취소할 수 없어요. 현재 상태를 유지했어요.';
}
