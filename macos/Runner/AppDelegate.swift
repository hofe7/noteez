import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // 메뉴바 앱: 스티커 창을 다 닫아도 종료하지 않고 메뉴바에 남는다.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
