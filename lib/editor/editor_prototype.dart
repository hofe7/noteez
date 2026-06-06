import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;

import '../models/sticky.dart';
import 'note_editor.dart';

/// NoteEditor(스티커 본문 후보) 검증용. 단일 에디터 동작 + 블록 변환을 함께 확인:
/// 하단 디버그 줄에 onChanged로 나온 블록들을 실시간 표시.
class EditorPrototypeApp extends StatelessWidget {
  const EditorPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [FlutterQuillLocalizations.delegate],
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: _Proto()),
      ),
    );
  }
}

class _Proto extends StatefulWidget {
  const _Proto();
  @override
  State<_Proto> createState() => _ProtoState();
}

class _ProtoState extends State<_Proto> {
  late List<Block> _blocks = [
    textBlock('첫 줄 — 드래그/Shift 화살표로 줄 넘어 선택, ⌘A 전체 선택'),
    textBlock('둘째 줄. 그냥 텍스트.'),
    todoBlock('체크박스 할 일 — 박스 탭하면 토글', false),
    todoBlock('완료된 할 일', true),
    textBlock('마지막 줄.'),
  ];

  String get _summary => _blocks
      .map((b) => switch (b) {
            TodoBlock t => '[${t.checked ? "x" : " "}]${t.text}',
            ImageBlock _ => '(img)',
            _ => b.text,
          })
      .join('  |  ');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: NoteEditor(
              initial: _blocks,
              autofocus: true,
              onChanged: (b) => setState(() => _blocks = b),
            ),
          ),
        ),
        const Divider(height: 1),
        Container(
          width: double.infinity,
          color: const Color(0xFFF3F1EA),
          padding: const EdgeInsets.all(10),
          child: Text('블록 ${_blocks.length}개:  $_summary',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ),
      ],
    );
  }
}
