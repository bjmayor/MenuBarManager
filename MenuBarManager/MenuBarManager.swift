import Cocoa

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    
    override init() {
        super.init()
        print("MenuBarManager: 初始化开始")
        setupStatusBar()
        print("MenuBarManager: 初始化完成")
    }
    
    private func setupStatusBar() {
        print("MenuBarManager: 开始设置状态栏")
        
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        print("MenuBarManager: 状态栏项目已创建: \(statusItem != nil)")
        
        // 设置按钮
        if let button = statusItem?.button {
            print("MenuBarManager: 获取到按钮，开始设置")
            button.title = "●"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.toolTip = "MenuBarManager - 点击测试"
            print("MenuBarManager: 按钮设置完成")
        } else {
            print("MenuBarManager: 错误 - 无法获取按钮")
        }
        
        // 检查状态栏是否可见
        if let statusItem = statusItem {
            print("MenuBarManager: 状态栏项目可见性: \(statusItem.isVisible)")
            print("MenuBarManager: 状态栏项目长度: \(statusItem.length)")
        }
        
        print("MenuBarManager: 状态栏设置完成")
    }
    
    @objc private func statusBarButtonClicked() {
        print("MenuBarManager: 按钮被点击了！")
        // 弹框已移除，不再显示
    }
}