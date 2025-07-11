import Cocoa

class CustomApplication: NSApplication {
    private var statusItem: NSStatusItem?
    private var lastAppCount = 0
    
    override func finishLaunching() {
        super.finishLaunching()
        
        // 设置为菜单栏应用（不在 Dock 中显示）
        setActivationPolicy(.accessory)
        
        // 立即创建状态栏图标
        createStatusBarIcon()
        
        // 启动定时器，每5秒自动刷新应用列表
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // 在主线程更新UI
            DispatchQueue.main.async {
                self.refreshAppListIfNeeded()
            }
        }
    }
    
    private func createStatusBarIcon() {
        print("🔄 开始创建状态栏图标...")
        
        // 使用 variableLength 来获得最高优先级
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            print("❌ 创建状态栏项目失败")
            return
        }
        
        // 强制设置为可见并优先显示
        statusItem.isVisible = true
        statusItem.behavior = .removalAllowed
        
        guard let button = statusItem.button else {
            print("❌ 获取状态栏按钮失败")
            return
        }
        
        // 设置按钮属性 - 使用简单有效的图标
        button.title = "⋯"
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        button.toolTip = "MenuBar Manager - 管理隐藏的菜单栏应用"
        button.target = self
        button.action = #selector(statusBarClicked)
        
        print("✅ 状态栏图标创建成功！")
        print("📍 应该看到 ⋯ 按钮")
    }
    
    @objc private func statusBarClicked() {
        print("🔄 状态栏按钮被点击")
        showMenuBarApps()
    }
    
    private func showMenuBarApps() {
        guard let statusItem = statusItem else { 
            print("❌ statusItem 为空")
            return 
        }
        
        print("🔄 开始显示菜单...")
        
        let menu = NSMenu()
        menu.title = "菜单栏应用管理"
        
        // 获取真正的菜单栏应用
        let menuBarApps = getRealMenuBarApps()
        
        // 添加菜单项
        let headerItem = NSMenuItem(title: "菜单栏应用 (共\(menuBarApps.count)个)：", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        if menuBarApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "未检测到菜单栏应用", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            menu.addItem(noAppsItem)
        } else {
            for app in menuBarApps {
                let menuItem = NSMenuItem(
                    title: app.localizedName ?? "未知应用",
                    action: #selector(activateApp(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = app
                
                // 添加应用图标
                if let icon = app.icon {
                    icon.size = NSSize(width: 16, height: 16)
                    menuItem.image = icon
                }
                
                menu.addItem(menuItem)
            }
        }
        
        // 添加分隔线和管理选项
        menu.addItem(NSMenuItem.separator())
        
        // 添加刷新选项
        let refreshItem = NSMenuItem(title: "刷新列表", action: #selector(refreshApps), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        // 添加退出选项
        let quitItem = NSMenuItem(title: "退出 MenuBar Manager", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // 直接显示菜单，而不是使用 performClick
        statusItem.menu = menu
        print("✅ 菜单已设置，应该会自动显示")
        
        // 清理菜单引用（重要！）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            statusItem.menu = nil
            print("🔄 菜单引用已清理")
        }
    }
    
    @objc private func quitApp() {
        print("🚪 用户选择退出应用")
        NSApplication.shared.terminate(nil)
    }
    
    private func refreshAppListIfNeeded() {
        let currentApps = getRealMenuBarApps()
        
        // 只有在应用数量发生变化时才刷新
        if currentApps.count != lastAppCount {
            lastAppCount = currentApps.count
            print("🔄 应用数量变化：\(currentApps.count) 个被隐藏的菜单栏应用")
            
            // 如果当前正在显示菜单，不要刷新（避免菜单消失）
            if statusItem?.menu == nil {
                // 这里可以添加更多的刷新逻辑，比如更新图标状态
                updateStatusIcon(hiddenAppCount: currentApps.count)
            }
        }
    }
    
    private func updateStatusIcon(hiddenAppCount: Int) {
        guard let button = statusItem?.button else { return }
        
        // 根据隐藏的应用数量更新工具提示
        if hiddenAppCount > 0 {
            button.toolTip = "MenuBar Manager - \(hiddenAppCount) 个隐藏的菜单栏应用"
        } else {
            button.toolTip = "MenuBar Manager - 没有隐藏的菜单栏应用"
        }
    }
    
    @objc private func refreshApps() {
        print("🔄 手动刷新应用列表")
        lastAppCount = -1  // 强制刷新
        refreshAppListIfNeeded()
    }
    
    // 改进的应用过滤逻辑 - 只显示真正被隐藏的应用
    private func getRealMenuBarApps() -> [NSRunningApplication] {
        let allApps = NSWorkspace.shared.runningApplications
        
        // 排除明显不需要的应用
        let excludedApps = [
            "com.menubarmanager.app",  // 我们自己的应用
            "MenuBarManager",          // 我们自己的应用名称
            
            // 浏览器和常规应用（通常不在菜单栏）
            "com.google.Chrome", "com.mozilla.firefox", "com.microsoft.edgemac", "com.apple.Safari",
            
            // 其他常见的不需要显示的应用
            "com.adobe.acc.installer", "com.adobe.CCLibrary", "com.microsoft.OneDrive", "com.dropbox.Dropbox"
        ]
        
        print("🔍 开始分析所有运行的应用...")
        
        let candidateApps = allApps.filter { app in
            guard let bundleId = app.bundleIdentifier,
                  let bundleName = app.localizedName else { 
                print("❌ 跳过没有bundleId或名称的应用")
                return false 
            }
            
            // 排除系统应用
            if bundleId.hasPrefix("com.apple.") { 
                print("🍎 跳过系统应用: \(bundleName)")
                return false 
            }
            
            // 排除明确不需要的应用
            if excludedApps.contains(bundleId) || excludedApps.contains(bundleName) { 
                print("🚫 跳过排除列表中的应用: \(bundleName)")
                return false 
            }
            
            // 排除助手应用 - 但是要保留一些重要的应用如 Postgres
            let helperPatterns = ["helper", "Helper", "renderer", "Renderer", "agent", "Agent", 
                                 "service", "Service", "daemon", "Daemon", "monitor", "Monitor", 
                                 "extension", "Extension", "plugin", "Plugin", "updater", "Updater",
                                 "launcher", "Launcher"]
            
            // 重要的应用例外 - 即使包含 helper 也要显示
            let importantApps = ["postgres", "docker", "database", "server", "mysql", "redis", "mongodb", "ollama"]
            
            let isImportantApp = importantApps.contains { important in
                bundleName.lowercased().contains(important) || bundleId.lowercased().contains(important)
            }
            
            let isHelperApp = helperPatterns.contains { pattern in
                bundleName.lowercased().contains(pattern.lowercased()) || 
                bundleId.lowercased().contains(pattern.lowercased())
            }
            
            // 如果是重要应用，即使是 helper 也要包含
            if isHelperApp && !isImportantApp { 
                print("🔧 跳过助手应用: \(bundleName) (\(bundleId))")
                return false 
            }
            
            // 只包含 accessory 应用（真正的菜单栏应用）
            let isAccessoryApp = app.activationPolicy == .accessory
            
            // 不能是隐藏的应用，必须有 bundle URL
            let isNotHidden = !app.isHidden
            let hasBundleURL = app.bundleURL != nil
            
            // 严格条件：只包含 accessory 应用
            let shouldInclude = isAccessoryApp && isNotHidden && hasBundleURL
            
            if shouldInclude {
                print("✅ 包含菜单栏应用: \(bundleName) (\(bundleId)) - \(app.activationPolicy.rawValue)")
            } else {
                print("❌ 排除应用: \(bundleName) - 激活策略: \(app.activationPolicy.rawValue)")
            }
            
            return shouldInclude
        }
        
        // 去重
        var seenBundleIds = Set<String>()
        let uniqueApps = candidateApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            if seenBundleIds.contains(bundleId) { 
                print("🔄 去重：移除重复的 \(app.localizedName ?? "未知")")
                return false 
            }
            seenBundleIds.insert(bundleId)
            return true
        }
        
        print("🔍 找到 \(uniqueApps.count) 个隐藏的菜单栏应用")
        return uniqueApps
    }
    
    // 尝试获取可见菜单栏宽度的估算
    private func getVisibleMenuBarWidth() -> CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        let screenWidth = screen.frame.width
        
        // 估算系统菜单项（时间、电池、WiFi等）占用的宽度
        let systemMenuWidth: CGFloat = 200  // 大概估算
        
        // 可用于第三方应用的宽度
        let availableWidth = screenWidth - systemMenuWidth
        
        return availableWidth
    }
    
    @objc private func activateApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? NSRunningApplication else { 
            print("❌ 无法获取应用对象")
            return 
        }
        
        print("🔄 尝试激活应用: \(app.localizedName ?? "未知") (\(app.bundleIdentifier ?? "未知"))")
        
        // 尝试多种激活方式
        var success = false
        
        // 1. 尝试标准激活
        success = app.activate(options: [])
        
        if success {
            print("✅ 标准激活成功")
            return
        }
        
        // 2. 尝试使用 NSWorkspace 激活
        if let bundleId = app.bundleIdentifier {
            print("🔄 尝试通过 NSWorkspace 激活...")
            success = NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, 
                                               options: [], 
                                               additionalEventParamDescriptor: nil, 
                                               launchIdentifier: nil)
            
            if success {
                print("✅ NSWorkspace 激活成功")
                return
            }
        }
        
        // 3. 尝试通过 URL 打开
        if let bundleURL = app.bundleURL {
            print("🔄 尝试通过 URL 打开应用...")
            NSWorkspace.shared.openApplication(at: bundleURL, 
                                              configuration: NSWorkspace.OpenConfiguration())
            print("✅ URL 打开完成")
            return
        }
        
        print("⚠️ 所有激活方式都失败了")
    }
}