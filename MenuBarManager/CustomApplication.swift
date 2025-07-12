import Cocoa

class CustomApplication: NSApplication {
    private var statusItem: NSStatusItem?
    private var lastAppCount = 0
    private var managerWindow: MenuBarAppManagerWindow?
    
    override func finishLaunching() {
        super.finishLaunching()
        
        // 设置为菜单栏应用（不在 Dock 中显示）
        setActivationPolicy(.accessory)
        
        // 设置应用图标
        setupAppIcon()
        
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
    
    private func setupAppIcon() {
        // 创建程序化应用图标
        let iconSize = NSSize(width: 512, height: 512)
        let image = NSImage(size: iconSize)
        
        image.lockFocus()
        
        // 创建圆角矩形背景
        let rect = NSRect(origin: .zero, size: iconSize)
        let path = NSBezierPath(roundedRect: rect, xRadius: 64, yRadius: 64)
        
        // 使用渐变背景
        let gradient = NSGradient(colors: [
            NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),  // 蓝色
            NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1.0)   // 深蓝色
        ])
        gradient?.draw(in: path, angle: 45)
        
        // 添加菜单栏图标 - 三条横线
        NSColor.white.setFill()
        let lineHeight: CGFloat = 20
        let lineSpacing: CGFloat = 30
        let lineWidth: CGFloat = 200
        let startY = (iconSize.height - (3 * lineHeight + 2 * lineSpacing)) / 2
        let startX = (iconSize.width - lineWidth) / 2
        
        for i in 0..<3 {
            let lineRect = NSRect(
                x: startX,
                y: startY + CGFloat(i) * (lineHeight + lineSpacing),
                width: lineWidth,
                height: lineHeight
            )
            let linePath = NSBezierPath(roundedRect: lineRect, xRadius: 10, yRadius: 10)
            linePath.fill()
        }
        
        // 添加小圆点表示"管理"
        let dotSize: CGFloat = 30
        let dotRect = NSRect(
            x: iconSize.width - 80,
            y: 80,
            width: dotSize,
            height: dotSize
        )
        let dotPath = NSBezierPath(ovalIn: dotRect)
        NSColor.white.setFill()
        dotPath.fill()
        
        image.unlockFocus()
        
        // 设置为应用图标
        NSApplication.shared.applicationIconImage = image
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
        
        // 使用 SF Symbol 图标而不是文字
        if let icon = NSImage(systemSymbolName: "line.3.horizontal.circle", accessibilityDescription: "MenuBar Manager") {
            icon.size = NSSize(width: 16, height: 16)
            button.image = icon
        } else {
            // 如果 SF Symbol 不可用，使用文字
            button.title = "⋯"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }
        
        button.toolTip = "MenuBar Manager - 管理隐藏的菜单栏应用"
        
        // 创建并设置菜单
        createMenu()
        
        print("✅ 状态栏图标创建成功！")
        print("📍 应该看到菜单栏图标")
    }
    
    private func createMenu() {
        guard let statusItem = statusItem else { 
            print("❌ statusItem 为空")
            return 
        }
        
        print("🔄 开始创建菜单...")
        
        let menu = NSMenu()
        menu.title = "菜单栏应用管理"
        
        // 添加智能管理功能
        let smartManageItem = NSMenuItem(title: "🧺 智能管理菜单栏", action: #selector(showSmartMenuBarManagement), keyEquivalent: "")
        smartManageItem.target = self
        menu.addItem(smartManageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加主要功能：打开管理窗口
        let manageItem = NSMenuItem(title: "📱 打开详细管理器", action: #selector(openManagerWindow), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 获取真正的菜单栏应用
        let menuBarApps = getRealMenuBarApps()
        
        // 添加应用列表信息
        let headerItem = NSMenuItem(title: "菜单栏应用 (共\(menuBarApps.count)个)：", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        if menuBarApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "未检测到菜单栏应用", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            menu.addItem(noAppsItem)
        } else {
            // 只显示前5个应用，其余的通过管理器查看
            let displayApps = Array(menuBarApps.prefix(5))
            for app in displayApps {
                let menuItem = NSMenuItem(
                    title: "• \(app.localizedName ?? "未知应用")",
                    action: nil,
                    keyEquivalent: ""
                )
                menuItem.isEnabled = false
                
                // 添加应用图标
                if let icon = app.icon {
                    icon.size = NSSize(width: 16, height: 16)
                    menuItem.image = icon
                }
                
                menu.addItem(menuItem)
            }
            
            if menuBarApps.count > 5 {
                let moreItem = NSMenuItem(title: "... 还有 \(menuBarApps.count - 5) 个应用", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        }
        
        // 添加分隔线和其他选项
        menu.addItem(NSMenuItem.separator())
        
        // 添加刷新选项
        let refreshItem = NSMenuItem(title: "刷新列表", action: #selector(refreshApps), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        // 添加退出选项
        let quitItem = NSMenuItem(title: "退出 MenuBar Manager", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // 永久设置菜单 - 不清理
        statusItem.menu = menu
        print("✅ 菜单已永久设置")
    }
    
    @objc private func showSmartMenuBarManagement() {
        print("🧺 显示智能菜单栏管理")
        
        let alert = NSAlert()
        alert.messageText = "🧺 菜单栏智能管理"
        alert.informativeText = """
        🎯 解决菜单栏空间不足的问题：
        
        📍 常见问题：
        • 新应用启动后在菜单栏看不到
        • 菜单栏空间被其他应用占满
        • 重要应用被挤到隐藏区域
        
        📍 解决方案：
        • 智能清理：暂时退出不必要的应用
        • 重启应用：让隐藏应用重新显示
        • 手动管理：学会使用 Command+拖拽
        
        选择解决方案：
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "📱 智能清理")
        alert.addButton(withTitle: "🔄 重启应用")
        alert.addButton(withTitle: "📚 学习管理")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            showMenuBarCleanup()
        case .alertSecondButtonReturn:
            showMenuBarAppRestart()
        case .alertThirdButtonReturn:
            showMenuBarTutorial()
        default:
            break
        }
    }
    
    private func showMenuBarCleanup() {
        // 智能识别可以清理的应用
        let allApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .accessory && 
            app.bundleIdentifier != nil &&
            !app.bundleIdentifier!.contains("com.menubarmanager.app")
        }
        
        if allApps.isEmpty {
            let alert = NSAlert()
            alert.messageText = "无需清理"
            alert.informativeText = "当前没有检测到可以清理的菜单栏应用。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        let appNames = allApps.prefix(3).map { $0.localizedName ?? "未知" }.joined(separator: "、")
        
        let alert = NSAlert()
        alert.messageText = "📱 智能清理菜单栏"
        alert.informativeText = """
        检测到 \(allApps.count) 个菜单栏应用：\(appNames)等
        
        📍 清理后的效果：
        • 释放菜单栏空间
        • 新应用能够正常显示
        • 需要时可以重新启动
        
        选择清理方式：
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "🧺 智能选择")
        alert.addButton(withTitle: "📱 全部清理")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            openManagerWindow()
        case .alertSecondButtonReturn:
            for app in allApps {
                app.terminate()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let successAlert = NSAlert()
                successAlert.messageText = "✅ 清理完成"
                successAlert.informativeText = "已清理 \(allApps.count) 个应用，菜单栏空间已释放！"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "确定")
                successAlert.runModal()
            }
        default:
            break
        }
    }
    
    private func showMenuBarAppRestart() {
        let allApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .accessory && 
            app.bundleIdentifier != nil &&
            !app.bundleIdentifier!.contains("com.menubarmanager.app")
        }
        
        if allApps.isEmpty {
            let alert = NSAlert()
            alert.messageText = "无应用可重启"
            alert.informativeText = "当前没有检测到需要重启的菜单栏应用。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "🔄 重启菜单栏应用"
        alert.informativeText = """
        检测到 \(allApps.count) 个菜单栏应用
        
        📍 重启的作用：
        • 让隐藏的应用重新显示
        • 重新排列菜单栏顺序
        • 解决应用不显示的问题
        
        是否继续？
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔄 开始重启")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            restartAllMenuBarApps(allApps)
        }
    }
    
    private func showMenuBarTutorial() {
        let alert = NSAlert()
        alert.messageText = "📚 macOS 菜单栏管理教程"
        alert.informativeText = """
        🎯 掌握 macOS 内置的菜单栏管理功能：
        
        📍 重新排序菜单栏图标：
        1. 按住 Command 键 (⌘)
        2. 用鼠标拖拽菜单栏图标到想要的位置
        3. 释放鼠标完成重新排序
        
        📍 管理菜单栏空间：
        • 将重要应用拖到左边（优先显示）
        • 将不常用应用拖到右边（可能被隐藏）
        • 定期清理不必要的菜单栏应用
        
        📍 其他技巧：
        • 使用专业工具如 Bartender（付费）
        • 在应用设置中关闭菜单栏图标
        • 调整屏幕分辨率增加菜单栏空间
        
        💡 记住：通过合理管理菜单栏，可以让重要应用始终可见！
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "我知道了")
        alert.runModal()
    }
    
    private func restartAllMenuBarApps(_ apps: [NSRunningApplication]) {
        let alert = NSAlert()
        alert.messageText = "正在重启..."
        alert.informativeText = "请稍等，正在重启 \(apps.count) 个菜单栏应用"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        
        DispatchQueue.global().async {
            for app in apps {
                app.terminate()
                Thread.sleep(forTimeInterval: 1.0)
                
                if let bundleId = app.bundleIdentifier {
                    DispatchQueue.main.async {
                        NSWorkspace.shared.launchApplication(
                            withBundleIdentifier: bundleId,
                            options: [.async],
                            additionalEventParamDescriptor: nil,
                            launchIdentifier: nil
                        )
                    }
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let successAlert = NSAlert()
                successAlert.messageText = "✅ 重启完成！"
                successAlert.informativeText = "所有菜单栏应用已重启，现在应该能看到你需要的应用了！"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "确定")
                successAlert.runModal()
            }
        }
        
        alert.runModal()
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
                    title: "🔍 \(app.localizedName ?? "未知应用")",
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
        
        // 添加刷新选项statusBarClicked
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
    
    @objc private func openManagerWindow() {
        print("🔄 打开应用管理器窗口")
        
        if managerWindow == nil {
            managerWindow = MenuBarAppManagerWindow(window: nil, customApp: self)
        }
        
        // 确保窗口在主线程显示
        DispatchQueue.main.async {
            self.managerWindow?.showWindow(nil)
            self.managerWindow?.window?.makeKeyAndOrderFront(nil)
            self.managerWindow?.window?.orderFrontRegardless()
            
            // 切换到正常应用模式以显示窗口
            self.setActivationPolicy(.regular)
            
            // 激活应用，确保窗口在前台
            NSApp.activate(ignoringOtherApps: true)
            
            print("✅ [窗口显示] 管理窗口已显示")
        }
        
        // 当窗口关闭时切换回菜单栏模式
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: managerWindow?.window, queue: .main) { _ in
            self.setActivationPolicy(.accessory)
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
        createMenu()  // 重新创建菜单
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
    
    @objc private func testMenuClick(_ sender: NSMenuItem) {
        print("🎯 [菜单栏管理] 开始处理菜单项点击")
        
        guard let app = sender.representedObject as? NSRunningApplication else { 
            print("❌ 无法获取应用对象")
            return 
        }
        
        let appName = app.localizedName ?? "未知应用"
        let bundleId = app.bundleIdentifier ?? "未知"
        print("🔄 处理应用: \(appName) (\(bundleId))")
        
        // 借鉴 Bartender 的思路：尝试让菜单栏图标变得可见
        // 方法1: 尝试触发应用的菜单栏更新
        triggerMenuBarVisibility(for: app)
        
        // 方法2: 如果是特定应用，提供特殊处理
        handleSpecialApps(app: app, bundleId: bundleId)
        
        // 显示操作反馈
        showActionFeedback(for: appName)
    }
    
    private func triggerMenuBarVisibility(for app: NSRunningApplication) {
        print("📍 [菜单栏管理] 尝试触发菜单栏图标可见性")
        
        // 方法1: 短暂切换到应用然后切回来，这会刷新菜单栏
        let currentApp = NSWorkspace.shared.frontmostApplication
        
        // 激活目标应用（这会让它的菜单栏图标更有可能显示）
        app.activate()
        
        // 等待一小段时间让菜单栏更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 切回到之前的应用
            currentApp?.activate()
            print("✅ [菜单栏管理] 菜单栏刷新操作完成")
        }
    }
    
    private func handleSpecialApps(app: NSRunningApplication, bundleId: String) {
        // 为特定应用提供专门的处理方式
        if bundleId.lowercased().contains("ollama") {
            print("📍 [特殊应用] 检测到 Ollama，打开管理界面")
            if let url = URL(string: "http://localhost:11434") {
                NSWorkspace.shared.open(url)
            }
        } else if bundleId.lowercased().contains("clashx") {
            print("📍 [特殊应用] 检测到 ClashX，尝试显示配置")
            // ClashX 通常有右键菜单，我们尝试模拟激活
            app.activate()
        }
        // 可以继续添加更多应用的特殊处理
    }
    
    private func showActionFeedback(for appName: String) {
        // 显示简洁的操作反馈，而不是阻塞式弹窗
        print("✅ [操作完成] 已尝试显示 \(appName) 的菜单栏图标")
        
        // 可选：显示一个非阻塞的通知
        let notification = NSUserNotification()
        notification.title = "MenuBar Manager"
        notification.informativeText = "已尝试显示 \(appName) 菜单栏图标"
        notification.soundName = nil // 静音
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func activateApp(_ sender: NSMenuItem) {
        print("🎯 [DEBUG] 菜单项被点击!")
        
        guard let app = sender.representedObject as? NSRunningApplication else { 
            print("❌ [DEBUG] 无法获取应用对象")
            return 
        }
        
        let appName = app.localizedName ?? "未知"
        let bundleId = app.bundleIdentifier ?? "未知"
        print("🔄 [DEBUG] 处理应用: \(appName) (\(bundleId))")
        
        // 尝试多种激活方式
        print("📍 [DEBUG] 尝试方法1: 基础激活")
        let activated = app.activate()
        print("📍 [DEBUG] 基础激活结果: \(activated)")
        
        print("📍 [DEBUG] 尝试方法2: 取消隐藏")
        app.unhide()
        
        print("📍 [DEBUG] 尝试方法3: NSWorkspace 激活")
        if let bundleId = app.bundleIdentifier {
            let wsActivated = NSWorkspace.shared.launchApplication(
                withBundleIdentifier: bundleId,
                options: [.async],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
            print("📍 [DEBUG] NSWorkspace 激活结果: \(wsActivated)")
        }
        
        // 如果是 Ollama，尝试打开网页界面
        if bundleId.lowercased().contains("ollama") {
            print("📍 [DEBUG] 检测到 Ollama，尝试打开网页界面")
            if let url = URL(string: "http://localhost:11434") {
                NSWorkspace.shared.open(url)
                print("📍 [DEBUG] 已尝试打开 Ollama 网页界面")
            }
        }
        
        print("✅ [DEBUG] 激活尝试完成")
    }
    
    private func forceShowAllMenuBarApps() {
        print("🔄 强制显示所有菜单栏应用...")
        
        // 方法1: 模拟按住 Option 键点击菜单栏的效果
        // 这是 macOS 的一个隐藏功能，可以显示所有菜单栏图标
        simulateOptionClickMenuBar()
        
        // 方法2: 尝试激活所有菜单栏应用
        let menuBarApps = getRealMenuBarApps()
        for app in menuBarApps {
            print("🔄 激活应用: \(app.localizedName ?? "未知")")
            
            // 尝试多种激活方式
            app.activate()
            app.unhide()
            
            // 使用 NSWorkspace 激活
            if let bundleId = app.bundleIdentifier,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                config.hides = false
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
            }
        }
        
        // 方法3: 发送全局系统事件
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.triggerMenuBarRefresh()
        }
    }
    
    private func simulateOptionClickMenuBar() {
        print("🔄 模拟 Option+点击 菜单栏...")
        
        // 创建一个 AppleScript 来模拟 Option 键操作
        let script = """
        tell application "System Events"
            -- 模拟按住 Option 键并点击菜单栏右侧
            key down option
            delay 0.1
            
            -- 尝试点击菜单栏的一个区域来触发显示所有图标
            try
                click at {1000, 10}
            end try
            
            delay 0.1
            key up option
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            _ = appleScript.executeAndReturnError(&errorInfo)
            
            if let error = errorInfo {
                print("⚠️ AppleScript 执行失败: \(error)")
            } else {
                print("✅ AppleScript 执行成功")
            }
        }
    }
    
    private func triggerMenuBarRefresh() {
        print("🔄 触发菜单栏刷新...")
        
        // 方法1: 发送窗口管理事件
        let notification = Notification(name: NSWorkspace.didActivateApplicationNotification)
        NotificationCenter.default.post(notification)
        
        // 方法2: 尝试使用 Core Graphics 事件
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 模拟 Command+空格 来触发 Spotlight，然后立即取消
        // 这有时会触发菜单栏刷新
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
           let spaceDown = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: true),
           let spaceUp = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: false),
           let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
            
            cmdDown.flags = .maskCommand
            spaceDown.flags = .maskCommand
            spaceUp.flags = .maskCommand
            
            cmdDown.post(tap: .cghidEventTap)
            spaceDown.post(tap: .cghidEventTap)
            spaceUp.post(tap: .cghidEventTap)
            cmdUp.post(tap: .cghidEventTap)
            
            // 立即发送 Escape 来取消 Spotlight
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let escDown = CGEvent(keyboardEventSource: source, virtualKey: 0x35, keyDown: true),
                   let escUp = CGEvent(keyboardEventSource: source, virtualKey: 0x35, keyDown: false) {
                    escDown.post(tap: .cghidEventTap)
                    escUp.post(tap: .cghidEventTap)
                }
            }
            
            print("✅ 已发送菜单栏刷新事件")
        }
    }
    
    // 为管理窗口提供 ClashX 重启功能
    func restartClashX(_ app: NSRunningApplication) {
        print("🎯 从 CustomApplication 重启 ClashX")
        
        // 显示进度提示
        let progressAlert = NSAlert()
        progressAlert.messageText = "正在重启 ClashX..."
        progressAlert.informativeText = "请稍等，ClashX 正在重启以获得菜单栏位置"
        progressAlert.alertStyle = .informational
        progressAlert.addButton(withTitle: "确定")
        
        // 异步处理重启
        DispatchQueue.global().async {
            // 终止 ClashX
            app.terminate()
            
            // 等待更长时间确保 ClashX 完全退出
            Thread.sleep(forTimeInterval: 3.0)
            
            // 重新启动 ClashX
            if let bundleId = app.bundleIdentifier {
                DispatchQueue.main.async {
                    NSWorkspace.shared.launchApplication(
                        withBundleIdentifier: bundleId,
                        options: [.async],
                        additionalEventParamDescriptor: nil,
                        launchIdentifier: nil
                    )
                    
                    // 显示成功提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        let successAlert = NSAlert()
                        successAlert.messageText = "🎯 ClashX 重启成功！"
                        successAlert.informativeText = """
                        ✅ ClashX 已重启并应该出现在菜单栏中！
                        
                        如果仍然看不到，请检查：
                        • ClashX 是否已经在菜单栏最右侧
                        • 尝试使用 Command+拖拽调整位置
                        • 或者退出其他不必要的菜单栏应用
                        """
                        successAlert.alertStyle = .informational
                        successAlert.addButton(withTitle: "确定")
                        successAlert.runModal()
                        
                        // 刷新应用列表
                        self.refreshApps()
                    }
                }
            }
        }
        
        progressAlert.runModal()
    }
}
