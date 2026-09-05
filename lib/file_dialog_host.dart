import 'package:window_manager/window_manager.dart';

/// macOS file_selector attaches panels to the main Flutter window. Keep that
/// normally hidden palette visible until its panel completes or is cancelled.
class FileDialogHost {
  FileDialogHost({
    required this.isVisible,
    required this.show,
    required this.focus,
    required this.hide,
  });

  final Future<bool> Function() isVisible;
  final Future<void> Function() show;
  final Future<void> Function() focus;
  final Future<void> Function() hide;
  bool _active = false;
  bool get active => _active;

  Future<T> run<T>(Future<T> Function() action) async {
    if (_active) throw StateError('A file dialog is already open.');
    _active = true;
    bool? wasVisible;
    try {
      wasVisible = await isVisible();
      await show();
      await focus();
      return await action();
    } finally {
      try {
        if (wasVisible == false) await hide();
      } finally {
        _active = false;
      }
    }
  }
}

final fileDialogHost = FileDialogHost(
  isVisible: windowManager.isVisible,
  show: windowManager.show,
  focus: windowManager.focus,
  hide: windowManager.hide,
);
