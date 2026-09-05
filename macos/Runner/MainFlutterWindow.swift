import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  private static var pasteMonitor: Any?
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

    // 서브창(스티커) 엔진에도 플러그인 등록 — window_manager 등을 쓰려면 필수.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    // ⌘V 붙여넣기: 포커스된 텍스트필드의 ⌘V는 네이티브 텍스트 입력이 처리해 Flutter
    // 키 이벤트로 안 오고, 한글 IME면 Flutter의 붙여넣기 단축키 매칭도 깨진다. 그래서
    // 여기(확실히 실행되는 awakeFromNib)에서 로컬 키 모니터로 ⌘V(키코드)를 직접 잡아
    // 클립보드 내용을 현재 키 창의 Flutter 엔진으로 보낸다(이미지/텍스트 모두).
    // (AppDelegate.applicationDidFinishLaunching은 xib delegate 연결 타이밍상 안 불림.)
    Self.pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      Self.handlePasteShortcut(event)
      return event
    }

    super.awakeFromNib()
  }

  private static func handlePasteShortcut(_ event: NSEvent) {
    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    // 물리 키코드로 V 판정(kVK_ANSI_V = 9). 한글 등 IME/레이아웃이 켜져 있어도
    // charactersIgnoringModifiers 는 "ㅍ" 같은 글자를 주므로 문자 매칭은 깨진다.
    guard mods == .command, event.keyCode == 9 else { return }
    guard let vc = NSApp.keyWindow?.contentViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "noteez/paste", binaryMessenger: vc.engine.binaryMessenger)
    if let png = pngFromPasteboard() {
      channel.invokeMethod("pasteImage", arguments: FlutterStandardTypedData(bytes: png))
    } else if let str = NSPasteboard.general.string(forType: .string), !str.isEmpty {
      channel.invokeMethod("pasteText", arguments: str)
    }
  }

  // 클립보드에서 이미지를 PNG Data로. 직접 이미지 데이터, 또는 이미지 파일 URL 둘 다.
  private static func pngFromPasteboard() -> Data? {
    let pb = NSPasteboard.general
    if let data = pb.data(forType: .png) { return data }
    if let tiff = pb.data(forType: .tiff),
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
      return png
    }
    if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
      for url in urls {
        if let img = NSImage(contentsOf: url),
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
          return png
        }
      }
    }
    return nil
  }
}
