import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// flutter_quill 검증용 프로토타입. 단일 에디터라 줄 넘는 드래그 선택·⌘A·⌘C/⌘V가
/// 기본으로 되는지, 체크리스트(체크박스)가 인라인으로 되는지 확인. 되면 이걸로
/// sticky 본문을 교체(블록 JSON ↔ Quill Delta 변환).
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
  late final QuillController _controller;

  @override
  void initState() {
    super.initState();
    final doc = Document()
      ..insert(
          0,
          'Noteez 에디터 프로토타입 (flutter_quill)\n'
          '첫 줄 — 여기서 아래로 드래그하면 줄을 넘어 선택돼야 해요.\n'
          '둘째 줄. Shift+↓ 로도 줄 넘는 선택 확인.\n'
          '셋째 줄. ⌘A 전체 선택 / ⌘C·⌘V 테스트.\n'
          '체크박스는 아래 툴바의 체크리스트 버튼으로.\n');
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuillSimpleToolbar(controller: _controller),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: QuillEditor.basic(controller: _controller),
          ),
        ),
      ],
    );
  }
}
