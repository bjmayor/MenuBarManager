import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // AppDelegate 现在不需要做任何事情
        // 所有功能都在 CustomApplication 中处理
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
