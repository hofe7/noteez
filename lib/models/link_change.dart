import 'dart:convert';

class LinkChange {
  const LinkChange(this.undoToken);
  final String? undoToken;
  String encode() => jsonEncode({'undoToken': undoToken});
  factory LinkChange.decode(Object? value) =>
      LinkChange((jsonDecode(value as String) as Map)['undoToken'] as String?);
}

class LinkChangeConflict implements Exception {
  const LinkChangeConflict();
  @override
  String toString() => '다른 변경이 있어 실행 취소할 수 없어요. 현재 상태를 유지했어요.';
}
