import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
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

    super.awakeFromNib()
  }
}
