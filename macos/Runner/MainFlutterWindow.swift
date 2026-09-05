import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  private static var pasteMonitor: Any?
  private static var pasteEditors = NSHashTable<FlutterViewController>.weakObjects()
  static var lifecycleChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    Self.lifecycleChannel = FlutterMethodChannel(
      name: "noteez/lifecycle", binaryMessenger: flutterViewController.engine.binaryMessenger)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 메인 창 = 검색/캡처 팔레트. 둥근 패널만 보이고 뒤 사각 배경은 안 보이게
    // NSWindow 자체를 투명·비불투명으로. (window_manager 의 transparent 만으론
    // NIB 로 만든 메인 창에서 검은 배경이 남는 문제 방지.)
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    // 창뿐 아니라 Flutter 렌더 surface 자체도 투명해야 검은 배경이 안 남음.
    flutterViewController.backgroundColor = .clear

    RegisterGeneratedPlugins(registry: flutterViewController)
    Self.registerPasteChannel(flutterViewController)

    // 서브창(스티커) 엔진에도 플러그인 등록 — window_manager 등을 쓰려면 필수.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      Self.registerPasteChannel(controller)
    }

    // Only intercept while a Noteez editor has focus. Returning nil prevents
    // Cocoa/Flutter from also pasting the same keystroke (including Korean IME).
    Self.pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      Self.handlePasteShortcut(event) ? nil : event
    }

    super.awakeFromNib()
  }

  private static func registerPasteChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "noteez/paste", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak controller] call, result in
      guard let controller = controller else { result(false); return }
      guard call.method == "setEnabled", let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented); return
      }
      if enabled { pasteEditors.add(controller) } else { pasteEditors.remove(controller) }
      result(true)
    }
  }

  private static func handlePasteShortcut(_ event: NSEvent) -> Bool {
    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard mods == .command, event.keyCode == 9 else { return false }
    guard let vc = NSApp.keyWindow?.contentViewController as? FlutterViewController,
      pasteEditors.contains(vc) else { return false }
    FlutterMethodChannel(name: "noteez/paste", binaryMessenger: vc.engine.binaryMessenger)
      .invokeMethod("paste", arguments: nil)
    return true
  }
}
