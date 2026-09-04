import 'package:flutter/material.dart';

import '../main_controller.dart';

/// 임시 컨트롤 창. 나중에 메뉴바/글로벌 핫키로 대체.
class ControlWindow extends StatelessWidget {
  const ControlWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noteez',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Noteez',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              AnimatedBuilder(
                animation: mainController,
                builder: (_, _) => Text(
                  '스티커 ${mainController.stickies.length}개',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => mainController.addSticky(),
                icon: const Icon(Icons.add),
                label: const Text('새 메모'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => mainController.importMarkdownFiles(),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Markdown 가져오기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => mainController.importMarkdownFolder(),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Markdown 폴더 가져오기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => mainController.importNotionZip(),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Notion ZIP 가져오기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => mainController.exportAllMarkdown(),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Markdown 내보내기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await mainController.exportBackup();
                  if (result != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('메모 ${result.noteCount}개 백업 완료')),
                    );
                  }
                },
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Noteez 백업 저장'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await mainController.stageRestore();
                  if (result != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('복원 준비 완료 · Noteez를 다시 시작해 주세요'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Noteez 백업 복원'),
              ),
              const Spacer(),
              const Text(
                '임시 컨트롤 창 — 나중에 메뉴바로 대체',
                style: TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
