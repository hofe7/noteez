import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var terminationPending = false

  // Cmd-Q and normal macOS termination also wait for every editor's final save.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !terminationPending else { return .terminateCancel }
    guard let channel = MainFlutterWindow.lifecycleChannel else { return .terminateNow }
    terminationPending = true
    channel.invokeMethod("flushPendingWrites", arguments: nil) { result in
      DispatchQueue.main.async {
        self.terminationPending = false
        sender.reply(toApplicationShouldTerminate: (result as? Bool) == true)
      }
    }
    return .terminateLater
  }

  // 메뉴바 앱: 스티커 창을 다 닫아도 종료하지 않고 메뉴바에 남는다.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
