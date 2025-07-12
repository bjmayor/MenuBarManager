import Cocoa

// 拖拽代理协议
protocol DraggableAppRowDelegate: AnyObject {
    func appRowDidStartDrag(_ row: DraggableAppRowView)
    func appRowDidEndDrag(_ row: DraggableAppRowView, at point: NSPoint)
    func shouldAcceptDrop(from source: DraggableAppRowView, to target: DraggableAppRowView) -> Bool
    func performDrop(from source: DraggableAppRowView, to target: DraggableAppRowView)
}

// 可拖拽的应用行视图
class DraggableAppRowView: NSView {
    weak var delegate: DraggableAppRowDelegate?
    var app: NSRunningApplication?
    private var dragStartPoint: NSPoint = .zero
    private var isDragging = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupDragAndDrop()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        // 注册为拖拽源
        registerForDraggedTypes([.string])
    }
    
    override func mouseDown(with event: NSEvent) {
        dragStartPoint = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)
        let distance = sqrt(pow(currentPoint.x - dragStartPoint.x, 2) + pow(currentPoint.y - dragStartPoint.y, 2))
        
        // 如果拖拽距离超过阈值，开始拖拽
        if distance > 5 && !isDragging {
            isDragging = true
            startDrag(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        super.mouseUp(with: event)
    }
    
    private func startDrag(with event: NSEvent) {
        guard let app = app else { return }
        
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        
        // 使用应用的 bundle ID 作为拖拽数据
        let bundleId = app.bundleIdentifier ?? app.localizedName ?? "unknown"
        pasteboard.setString(bundleId, forType: .string)
        
        // 创建拖拽图像
        let dragImage = createDragImage()
        
        delegate?.appRowDidStartDrag(self)
        
        // 创建 NSDraggingItem 并设置正确的 frame
        let draggingItem = NSDraggingItem(pasteboardWriter: bundleId as NSString)
        
        // 确保 draggingFrame 不为零
        let validBounds = bounds.size.width > 0 && bounds.size.height > 0 ? bounds : NSRect(x: 0, y: 0, width: 100, height: 60)
        draggingItem.setDraggingFrame(validBounds, contents: dragImage)
        
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    private func createDragImage() -> NSImage {
        // 确保图像大小不为零
        let imageSize = bounds.size.width > 0 && bounds.size.height > 0 ? bounds.size : NSSize(width: 100, height: 60)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        // 如果视图还没有正确布局，创建一个简单的占位符图像
        if bounds.size.width <= 0 || bounds.size.height <= 0 {
            NSColor.controlBackgroundColor.setFill()
            NSRect(origin: .zero, size: imageSize).fill()
            
            // 添加一些简单的内容
            let text = app?.localizedName ?? "App"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor
            ]
            let attrString = NSAttributedString(string: text, attributes: attrs)
            let textRect = NSRect(x: 10, y: 20, width: imageSize.width - 20, height: 20)
            attrString.draw(in: textRect)
        } else {
            // 渲染实际视图
            if let layer = layer {
                let context = NSGraphicsContext.current!.cgContext
                layer.render(in: context)
            }
        }
        
        image.unlockFocus()
        return image
    }
    
    // MARK: - NSDraggingDestination
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let sourceId = sender.draggingPasteboard.string(forType: .string),
              let sourceRow = findRowWithBundleId(sourceId) else {
            return false
        }
        
        if delegate?.shouldAcceptDrop(from: sourceRow, to: self) == true {
            delegate?.performDrop(from: sourceRow, to: self)
            return true
        }
        
        return false
    }
    
    private func findRowWithBundleId(_ bundleId: String) -> DraggableAppRowView? {
        // 这个方法需要从父视图中查找
        return superview?.subviews.compactMap { $0 as? DraggableAppRowView }
            .first { $0.app?.bundleIdentifier == bundleId || $0.app?.localizedName == bundleId }
    }
}

// MARK: - NSDraggingSource

extension DraggableAppRowView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        delegate?.appRowDidEndDrag(self, at: screenPoint)
        isDragging = false
    }
}

class MenuBarAppManagerWindow: NSWindowController {
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var menuBarApps: [NSRunningApplication] = []
    private var appSwitches: [String: NSSwitch] = [:]
    private var appRows: [String: NSView] = [:]
    private weak var customApp: CustomApplication?
    
    init(window: NSWindow?, customApp: CustomApplication? = nil) {
        let windowRect = NSMakeRect(0, 0, 600, 700)
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        self.customApp = customApp
        print("🎯 [初始化] MenuBarAppManagerWindow init 被调用")
        setupWindow()
        setupUI()  // 直接在init中调用
        loadMenuBarApps()  // 也直接调用
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        print("🎯 [窗口加载] windowDidLoad 被调用 - 但UI已在init中设置")
    }
    
    private func setupWindow() {
        guard let window = self.window else { return }
        
        window.title = "MenuBar Manager - 菜单栏应用管理"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 400)
        
        // 设置窗口层级，确保在最前面
        window.level = .floating
        window.orderFrontRegardless()
        
        // 添加调试输出
        print("✅ [窗口设置] 窗口已配置，大小: \(window.frame.size)")
    }
    
    private func setupUI() {
        guard let window = self.window else { 
            print("❌ [UI设置] window 为空")
            return 
        }
        
        print("✅ [UI设置] 开始设置UI")
        
        // 创建主容器
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = contentView
        
        print("✅ [UI设置] 设置了contentView")
        
        // 创建标题
        let titleLabel = NSTextField(labelWithString: "🎯 MenuBar Manager - 应用管理")
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        
        // 创建说明标签
        let instructionLabel = NSTextField(labelWithString: "💡 了解：为什么 Bartender 可以直接管理菜单栏？")
        instructionLabel.isEditable = false
        instructionLabel.isBordered = false
        instructionLabel.backgroundColor = .clear
        instructionLabel.font = NSFont.systemFont(ofSize: 12)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.alignment = .center
        instructionLabel.cell?.wraps = true
        instructionLabel.cell?.isScrollable = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(instructionLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建滚动视图和堆栈视图
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .centerX
        stackView.distribution = .fill
        stackView.wantsLayer = true
        stackView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        scrollView.documentView = stackView
        contentView.addSubview(scrollView)
        
        // 创建刷新按钮
        let refreshButton = NSButton(title: "🔄 刷新应用列表", target: self, action: #selector(refreshApps))
        refreshButton.bezelStyle = .rounded
        contentView.addSubview(refreshButton)
        
        // 创建 Bartender 对比按钮
        let bartenderInfoButton = NSButton(title: "🤖 为什么 Bartender 可以直接管理？", target: self, action: #selector(showBartenderComparison))
        bartenderInfoButton.bezelStyle = .rounded
        contentView.addSubview(bartenderInfoButton)
        
        // 创建按钮容器
        let buttonContainer = NSView()
        contentView.addSubview(buttonContainer)
        
        buttonContainer.addSubview(refreshButton)
        buttonContainer.addSubview(bartenderInfoButton)
        
        // 设置约束
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        bartenderInfoButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 说明标签
            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: -20),
            
            // 按钮容器
            buttonContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // 刷新按钮
            refreshButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            refreshButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 120),
            
            // Bartender 对比按钮
            bartenderInfoButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            bartenderInfoButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            bartenderInfoButton.widthAnchor.constraint(equalToConstant: 240)
        ])
        
        // 设置堆栈视图约束
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentView.bottomAnchor, constant: -10)
        ])
        
        print("✅ [UI设置] UI设置完成")
    }
    
    @objc private func showBartenderComparison() {
        print("🤖 显示 Bartender 对比说明")
        
        let alert = NSAlert()
        alert.messageText = "🤖 为什么 Bartender 可以直接管理菜单栏？"
        alert.informativeText = """
        🔍 Bartender 的技术实现原理：
        
        📍 核心技术差异：
        • 🤖 Bartender：使用系统级 API 和私有框架
        • 🛡️ 需要系统管理员权限和特殊签名
        • 💰 收费软件，可以承担开发成本
        
        • 📱 本应用：使用公开 API 和沙盒限制
        • ✅ 安全合规，不需要特殊权限
        • 🆓 免费开源，但功能有限
        
        📍 Bartender 的高级技术：
        1️⃣ 私有 API 调用：直接操作 WindowServer
        2️⃣ 系统注入：在系统层面拦截菜单栏事件
        3️⃣ 虚拟菜单栏：创建一个隐藏的第二菜单栏
        4️⃣ 特殊签名：获得 Apple 的特殊开发者权限
        
        📍 我们的替代方案：
        • 🔄 重启应用重新获得优先级
        • 📚 智能指导手动管理
        • 🔍 帮助识别可清理的应用
        • 💱 配合 Command+拖拽 原生功能
        
        💡 结论：
        Bartender 用的是 "黑科技" + 付费授权，
        我们用的是 "安全合规" + 智能辅助！
        
        想了解更多技术细节吗？
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔍 深入了解")
        alert.addButton(withTitle: "📚 学习替代方案")
        alert.addButton(withTitle: "我知道了")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            showBartenderTechnicalDetails()
        case .alertSecondButtonReturn:
            showAlternativeSolutions()
        default:
            break
        }
    }
    
    private func showBartenderTechnicalDetails() {
        let alert = NSAlert()
        alert.messageText = "🔬 Bartender 深层技术分析"
        alert.informativeText = """
        🤖 Bartender 的“黑科技”实现：
        
        📍 1. WindowServer 直接操作
        • 绕过 AppKit 框架，直接调用 Core Graphics
        • 使用未公开的 CGSGetMenuBarData() 等 API
        • 直接操作菜单栏的底层数据结构
        
        📍 2. 系统注入技术
        • 在 WindowServer 进程中注入代码
        • 拦截所有菜单栏相关的系统调用
        • 修改菜单栏显示逻辑
        
        📍 3. 虚拟菜单栏架构
        • 创建一个不可见的第二菜单栏
        • 将隐藏的应用移动到虚拟菜单栏
        • 通过点击 Bartender 图标显示/隐藏
        
        📍 4. 特殊开发者权限
        • Apple 的特殊签名证书
        • 系统级权限调用
        • 可以绕过沙盒限制
        
        🚫 为什么我们不这么做？
        • 🚨 安全风险：可能被 macOS 更新破坏
        • 📜 违反 App Store 规则
        • 💰 需要昂贵的企业开发者计划
        • 🔒 用户需要禁用 SIP（系统完整性保护）
        
        💡 总结：
        Bartender 用的是“高危高回报”的方式，
        我们选择“安全可靠”的路线！
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "我知道了")
        alert.runModal()
    }
    
    private func showAlternativeSolutions() {
        let alert = NSAlert()
        alert.messageText = "📚 安全的菜单栏管理方案"
        alert.informativeText = """
        🎯 我们的安全替代方案：
        
        🔄 1. 智能重启策略
        • 重启应用重新获得菜单栏优先级
        • 新启动的应用通常会显示在最前面
        • 100% 安全，不需要特殊权限
        
        💱 2. 手动指导系统
        • 智能识别可以清理的应用
        • 提供详细的操作步骤
        • 教会用户使用 macOS 原生功能
        
        🔍 3. 应用分析工具
        • 检测并分类菜单栏应用
        • 识别低优先级和重要应用
        • 提供个性化建议
        
        📚 4. 教育和指导
        • 深入讲解 Command+拖拽 功能
        • 分享菜单栏管理最佳实践
        • 提供多种解决方案
        
        💡 优势对比：
        ✅ 安全性：不需要系统级权限
        ✅ 兼容性：macOS 更新不会破坏
        ✅ 教育性：学会原生系统功能
        ✅ 免费性：完全免费开源
        
        想要实现哪种解决方案？
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔄 启动智能重启")
        alert.addButton(withTitle: "💱 获取手动指导")
        alert.addButton(withTitle: "📚 学习最佳实践")
        alert.addButton(withTitle: "我知道了")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            showAppRestartOptions()
        case .alertSecondButtonReturn:
            suggestAppsToHide()
        case .alertThirdButtonReturn:
            showDetailedMenuBarTutorial()
        default:
            break
        }
    }
    
    private func showAppRestartOptions() {
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleId = app.bundleIdentifier,
                  let name = app.localizedName,
                  app.activationPolicy == .accessory else { return false }
            
            return !bundleId.hasPrefix("com.apple.") && 
                   !bundleId.contains("com.menubarmanager.app")
        }
        
        if runningApps.isEmpty {
            let alert = NSAlert()
            alert.messageText = "无菜单栏应用"
            alert.informativeText = "当前没有检测到需要管理的菜单栏应用。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        let appNames = runningApps.prefix(5).map { $0.localizedName ?? "未知" }.joined(separator: "、")
        let moreCount = max(0, runningApps.count - 5)
        
        let alert = NSAlert()
        alert.messageText = "🔄 重启菜单栏应用"
        alert.informativeText = """
        检测到以下菜单栏应用：
        \(appNames)\(moreCount > 0 ? "等 \(moreCount) 个应用" : "")
        
        📍 重启应用的作用：
        • 让隐藏的应用重新获得菜单栏位置
        • 解决新启动应用不显示的问题
        • 重新排列菜单栏顺序
        
        选择操作：
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔄 全部重启")
        alert.addButton(withTitle: "🔍 选择重启")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            restartAllMenuBarApps(runningApps)
        case .alertSecondButtonReturn:
            // 重新加载应用列表让用户手动选择
            loadMenuBarApps()
        default:
            break
        }
    }
    
    private func restartAllMenuBarApps(_ apps: [NSRunningApplication]) {
        let alert = NSAlert()
        alert.messageText = "正在重启应用..."
        alert.informativeText = "请稍等，正在重启 \(apps.count) 个菜单栏应用"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        
        DispatchQueue.global().async {
            for (index, app) in apps.enumerated() {
                let appName = app.localizedName ?? "未知"
                print("🔄 [重启 \(index+1)/\(apps.count)] \(appName)")
                
                // 退出应用
                app.terminate()
                
                // 等待一段时间
                Thread.sleep(forTimeInterval: 1.0)
                
                // 重新启动
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
                
                // 间隔一下再重启下一个
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // 完成提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let successAlert = NSAlert()
                successAlert.messageText = "✅ 重启完成！"
                successAlert.informativeText = "所有菜单栏应用已重启，现在应该能看到你需要的应用了！"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "确定")
                successAlert.runModal()
                
                self.loadMenuBarApps()
            }
        }
        
        alert.runModal()
    }
    
    @objc private func refreshApps() {
        loadMenuBarApps()
    }
    
    @objc private func showTutorial() {
        let alert = NSAlert()
        alert.messageText = "🎯 ClashX 菜单栏显示解决方案"
        alert.informativeText = """
        🚀 快速解决 ClashX 不在菜单栏显示的问题：
        
        📍 方法1：重启 ClashX（最有效）
        • 退出当前的 ClashX
        • 重新启动 ClashX
        • 它将获得菜单栏中的优先位置
        
        📍 方法2：清理菜单栏空间
        • 退出一些不必要的菜单栏应用
        • 为 ClashX 腾出显示空间
        
        📍 方法3：使用 Command+拖拽
        • 按住 Command 键 (⌘)
        • 拖拽菜单栏图标重新排序
        • 将重要应用（如 ClashX）拖到左边
        
        📍 方法4：检查应用设置
        • 在 ClashX 设置中确认"显示菜单栏图标"已开启
        • 有些应用可能被意外隐藏
        
        💡 提示：通过合理管理菜单栏空间，可以确保重要应用始终可见！
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "我知道了")
        alert.addButton(withTitle: "🔍 检测 ClashX")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            detectAndFixClashX()
        }
    }
    
    private func detectAndFixClashX() {
        print("🔍 检测 ClashX 状态...")
        
        // 查找 ClashX 应用
        let clashXApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleId = app.bundleIdentifier,
                  let name = app.localizedName else { return false }
            return bundleId.lowercased().contains("clashx") || 
                   name.lowercased().contains("clashx")
        }
        
        if clashXApps.isEmpty {
            // ClashX 没有运行
            let alert = NSAlert()
            alert.messageText = "ClashX 未运行"
            alert.informativeText = """
            🔍 检测结果：ClashX 当前没有运行
            
            解决方案：
            • 启动 ClashX 应用
            • 启动后它将自动出现在菜单栏中
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
        } else {
            // ClashX 正在运行但可能不可见
            let clashX = clashXApps.first!
            let alert = NSAlert()
            alert.messageText = "找到 ClashX！"
            alert.informativeText = """
            ✅ 检测结果：ClashX 正在运行
            应用名称：\(clashX.localizedName ?? "ClashX")
            
            如果你在菜单栏看不到 ClashX 图标，这是因为菜单栏空间不足。
            
            选择解决方案：
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "🔄 重启 ClashX")
            alert.addButton(withTitle: "📱 管理菜单栏空间")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                handleClashXDisplay(clashX)
            case .alertSecondButtonReturn:
                showMenuBarCleanupOptions()
            default:
                break
            }
        }
    }
    
    private func loadMenuBarApps() {
        print("🔄 [应用加载] 开始加载菜单栏应用...")
        
        // 确保在主线程执行 UI 更新
        DispatchQueue.main.async {
            // 清除现有视图
            self.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.appSwitches.removeAll()
            self.appRows.removeAll()
            
            // 获取菜单栏应用
            self.menuBarApps = self.getRealMenuBarApps()
            
            print("📱 [应用加载] 检测到 \(self.menuBarApps.count) 个菜单栏应用")
            
            if self.menuBarApps.isEmpty {
                let noAppsLabel = NSTextField(labelWithString: "未检测到菜单栏应用")
                noAppsLabel.textColor = .secondaryLabelColor
                noAppsLabel.alignment = .center
                noAppsLabel.font = NSFont.systemFont(ofSize: 14)
                noAppsLabel.isEditable = false
                noAppsLabel.isBordered = false
                noAppsLabel.backgroundColor = .clear
                self.stackView.addArrangedSubview(noAppsLabel)
                print("⚠️ [应用加载] 没有找到菜单栏应用")
                return
            }
            
            // 为每个应用创建行
            for (index, app) in self.menuBarApps.enumerated() {
                let appName = app.localizedName ?? "未知应用"
                print("📋 [应用加载] 正在添加应用 \(index + 1): \(appName)")
                
                let appRow = self.createAppRow(for: app)
                self.stackView.addArrangedSubview(appRow)
                
                // 存储行引用
                if let bundleId = app.bundleIdentifier {
                    self.appRows[bundleId] = appRow
                }
            }
            
            print("✅ [应用加载] 已成功加载 \(self.menuBarApps.count) 个菜单栏应用")
            
            // 强制布局更新
            self.stackView.needsLayout = true
            self.scrollView.needsLayout = true
            self.window?.contentView?.needsLayout = true
        }
    }
    
    private func createAppRow(for app: NSRunningApplication) -> NSView {
        let rowView = DraggableAppRowView()
        rowView.app = app
        rowView.delegate = self
        rowView.wantsLayer = true
        rowView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        rowView.layer?.cornerRadius = 8
        
        // 拖拽手柄图标
        let dragHandle = NSTextField(labelWithString: "⋮⋮")
        dragHandle.font = NSFont.systemFont(ofSize: 16)
        dragHandle.textColor = .tertiaryLabelColor
        dragHandle.isEditable = false
        dragHandle.isBordered = false
        dragHandle.backgroundColor = .clear
        dragHandle.alignment = .center
        
        // 应用图标
        let iconView = NSImageView()
        if let icon = app.icon {
            iconView.image = icon
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        
        // 应用名称和信息
        let appName = app.localizedName ?? "未知应用"
        let bundleId = app.bundleIdentifier ?? "unknown"
        
        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        
        let idLabel = NSTextField(labelWithString: bundleId)
        idLabel.font = NSFont.systemFont(ofSize: 11)
        idLabel.textColor = .secondaryLabelColor
        idLabel.isEditable = false
        idLabel.isBordered = false
        idLabel.backgroundColor = .clear
        
        // 状态标签
        let statusLabel = NSTextField(labelWithString: getAppStatus(app))
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        
        // 开关
        let toggle = NSSwitch()
        toggle.state = .on // 默认开启，因为这些应用当前是在运行的
        toggle.target = self
        toggle.action = #selector(toggleAppVisibility(_:))
        
        // 存储应用信息到开关
        toggle.identifier = NSUserInterfaceItemIdentifier(bundleId)
        appSwitches[bundleId] = toggle
        
        // 布局容器
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.spacing = 2
        infoStack.alignment = .leading
        infoStack.addArrangedSubview(nameLabel)
        infoStack.addArrangedSubview(idLabel)
        infoStack.addArrangedSubview(statusLabel)
        
        // 添加子视图
        rowView.addSubview(dragHandle)
        rowView.addSubview(iconView)
        rowView.addSubview(infoStack)
        rowView.addSubview(toggle)
        
        // 设置约束
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 拖拽手柄
            dragHandle.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 8),
            dragHandle.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 20),
            
            // 图标
            iconView.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            // 信息堆栈
            infoStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            infoStack.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            
            // 开关
            toggle.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            toggle.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            // 行高度
            rowView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // 设置行宽度约束
        rowView.translatesAutoresizingMaskIntoConstraints = false
        rowView.widthAnchor.constraint(equalToConstant: 520).isActive = true
        
        return rowView
    }
    
    private func getAppStatus(_ app: NSRunningApplication) -> String {
        var status = "运行中"
        
        if app.activationPolicy == .accessory {
            status += " • 菜单栏应用"
        }
        
        if app.isHidden {
            status += " • 已隐藏"
        }
        
        return status
    }
    
    @objc private func toggleAppVisibility(_ sender: NSSwitch) {
        guard let bundleId = sender.identifier?.rawValue,
              let app = menuBarApps.first(where: { $0.bundleIdentifier == bundleId }) else {
            print("❌ 无法找到对应的应用")
            return
        }
        
        let appName = app.localizedName ?? "未知应用"
        
        if sender.state == .on {
            // 开启 - 让应用获得菜单栏位置
            print("🔛 尝试让 \(appName) 显示在菜单栏")
            makeAppVisible(app)
        } else {
            // 关闭 - 释放菜单栏空间
            print("🔴 释放菜单栏空间：隐藏/退出 \(appName)")
            hideAppFromMenuBar(app, sender: sender)
        }
    }
    
    private func makeAppVisible(_ app: NSRunningApplication) {
        let appName = app.localizedName ?? "未知应用"
        print("📍 让 \(appName) 在菜单栏中显示")
        
        let alert = NSAlert()
        alert.messageText = "让 \(appName) 显示在菜单栏"
        alert.informativeText = """
        🎯 解决菜单栏空间不足的方案：
        
        📍 方法1：重启应用（推荐）
        • 退出当前的 \(appName)
        • 重新启动 \(appName)
        • 新启动的应用通常会获得菜单栏位置
        
        📍 方法2：清理其他应用
        • 先退出一些不必要的菜单栏应用
        • 为 \(appName) 腾出显示空间
        • 然后重新启动 \(appName)
        
        📍 方法3：手动调整位置
        • 按住 Command 键 (⌘)
        • 拖拽菜单栏图标重新排序
        • 将重要应用拖到左边
        
        选择操作方式：
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔄 重启应用")
        alert.addButton(withTitle: "📱 清理其他应用")
        alert.addButton(withTitle: "📚 教程指导")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            restartApp(app)
        case .alertSecondButtonReturn:
            showMenuBarCleanupOptions()
        case .alertThirdButtonReturn:
            showDetailedMenuBarTutorial()
        default:
            break
        }
    }
    
    private func hideAppFromMenuBar(_ app: NSRunningApplication, sender: NSSwitch) {
        let appName = app.localizedName ?? "未知应用"
        print("📍 尝试隐藏 \(appName) 释放菜单栏空间")
        
        let alert = NSAlert()
        alert.messageText = "隐藏 \(appName)"
        alert.informativeText = """
        📍 由于 macOS 安全限制，本应用无法直接退出其他应用。
        
        但我们可以指导你手动操作：
        
        💱 方法1：右键菜单（推荐）
        • 右键点击菜单栏中的 \(appName) 图标
        • 选择 "退出" 或 "Quit \(appName)"
        
        ⌨️ 方法2：快捷键
        • 点击 \(appName) 图标激活应用
        • 按 Command+Q 退出
        
        🔄 方法3：活动监视器
        • 打开“活动监视器”应用
        • 找到 \(appName) 进程并强制退出
        
        选择操作方式：
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "📚 打开活动监视器")
        alert.addButton(withTitle: "💱 激活应用")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.launchApplication(
                withBundleIdentifier: "com.apple.ActivityMonitor",
                options: [.async],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
        case .alertSecondButtonReturn:
            app.activate()
        default:
            sender.state = .on  // 重置开关状态
        }
    }
    
    private func handleClashXDisplay(_ app: NSRunningApplication) {
        print("🎯 专门处理 ClashX 显示问题")
        
        let alert = NSAlert()
        alert.messageText = "让 ClashX 显示在菜单栏"
        alert.informativeText = """
        🎯 ClashX 菜单栏显示解决方案：
        
        📍 方法1：重启 ClashX（推荐）
        • 退出当前的 ClashX
        • 重新启动 ClashX
        • 它将获得菜单栏中的优先位置
        
        📍 方法2：清理其他应用
        • 退出一些不常用的菜单栏应用
        • 为 ClashX 腾出空间
        
        📍 方法3：使用 Command+拖拽
        • 按住 Command 键拖拽菜单栏图标调整顺序
        • 将 ClashX 拖到更显眼的位置
        
        选择解决方案：
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔄 重启 ClashX")
        alert.addButton(withTitle: "📱 清理其他应用")
        alert.addButton(withTitle: "📚 查看详细教程")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            restartClashX(app)
        case .alertSecondButtonReturn:
            showMenuBarCleanupOptions()
        case .alertThirdButtonReturn:
            showDetailedMenuBarTutorial()
        default:
            break
        }
    }
    
    private func restartApp(_ app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }
        
        let appName = app.localizedName ?? "未知应用"
        print("🔄 重启应用: \(appName)")
        
        // 先终止应用
        app.terminate()
        
        // 等待应用完全退出，然后重新启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NSWorkspace.shared.launchApplication(
                withBundleIdentifier: bundleId,
                options: [.async],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
            
            // 显示成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let successAlert = NSAlert()
                successAlert.messageText = "✅ 重启完成"
                successAlert.informativeText = "\(appName) 已重启，现在应该在菜单栏中显示了！"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "确定")
                successAlert.runModal()
                
                // 刷新应用列表
                self.loadMenuBarApps()
            }
        }
    }
    
    private func restartClashX(_ app: NSRunningApplication) {
        // 使用主应用的 restartClashX 方法
        if let customApp = customApp {
            customApp.restartClashX(app)
        } else {
            // 备用方案：直接重启
            restartApp(app)
        }
    }
    
    private func showMenuBarCleanupOptions() {
        print("📱 显示菜单栏清理选项")
        
        let alert = NSAlert()
        alert.messageText = "📱 清理菜单栏空间"
        alert.informativeText = """
        🧹 建议清理的菜单栏应用类型：
        
        📍 可以暂时退出的应用：
        • 监控类应用（iStat Menus、Activity Monitor）
        • 下载工具（Downie、Permute）
        • 不常用的工具应用
        • 游戏类应用的菜单栏工具
        
        📍 建议保留的重要应用：
        • 网络代理（ClashX、Surge、V2rayU）
        • 密码管理器（1Password、Bitwarden）
        • 系统监控工具
        • 开发工具（Docker、Postgres）
        
        选择清理方式：
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "🔍 查看全部应用")
        alert.addButton(withTitle: "🧺 一键清理建议")
        alert.addButton(withTitle: "📚 手动管理教程")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // 重新加载应用列表，重点关注可以清理的应用
            loadMenuBarApps()
        case .alertSecondButtonReturn:
            suggestAppsToHide()
        case .alertThirdButtonReturn:
            showDetailedMenuBarTutorial()
        default:
            break
        }
    }
    
    private func suggestAppsToHide() {
        print("🧺 智能推荐可以隐藏的应用")
        
        // 分析当前菜单栏应用，找出可以隐藏的
        let lowPriorityKeywords = [
            "monitor", "stats", "meter", "temperature", "fan", "cpu", "memory",
            "download", "upload", "converter", "cleaner", "backup",
            "game", "entertainment", "music", "video", "photo"
        ]
        
        let suggestedToHide = menuBarApps.filter { app in
            guard let name = app.localizedName?.lowercased(),
                  let bundleId = app.bundleIdentifier?.lowercased() else { return false }
            
            return lowPriorityKeywords.contains { keyword in
                name.contains(keyword) || bundleId.contains(keyword)
            }
        }
        
        if suggestedToHide.isEmpty {
            let alert = NSAlert()
            alert.messageText = "无需清理"
            alert.informativeText = "当前菜单栏应用看起来都是必要的，建议使用 Command+拖拽 来调整应用顺序。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        let appNames = suggestedToHide.map { $0.localizedName ?? "未知" }.joined(separator: "、")
        
        let alert = NSAlert()
        alert.messageText = "🧺 智能清理建议"
        alert.informativeText = """
        根据分析，以下应用可能不是紧急必需的：
        
        📱 建议手动退出：
        \(appNames)
        
        📍 提示：由于 macOS 沙盒限制，本应用无法直接退出其他应用。
        但我们可以指导你手动操作：
        
        1️⃣ 右键点击菜单栏应用图标
        2️⃣ 选择 "退出" 或 "Quit"
        3️⃣ 或者使用 Command+Q 快捷键
        
        需要时可以再次启动这些应用。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "📚 学习手动操作")
        alert.addButton(withTitle: "🔍 查看应用列表")
        alert.addButton(withTitle: "确定")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            showManualQuitTutorial(for: suggestedToHide)
        case .alertSecondButtonReturn:
            // 手动选择
            loadMenuBarApps()
        default:
            break
        }
    }
    
    private func showManualQuitTutorial(for apps: [NSRunningApplication]) {
        let appDetails = apps.map { app in
            let name = app.localizedName ?? "未知"
            let bundleId = app.bundleIdentifier ?? ""
            return "• \(name) (\(bundleId))"
        }.joined(separator: "\n")
        
        let alert = NSAlert()
        alert.messageText = "📚 手动退出指导"
        alert.informativeText = """
        🎯 建议手动退出以下应用以释放菜单栏空间：
        
        \(appDetails)
        
        📍 手动退出步骤：
        
        💱 方法1：右键菜单
        1. 右键点击菜单栏中的应用图标
        2. 选择 "退出" 或 "Quit ×××"
        
        ⌨️ 方法2：快捷键
        1. 点击应用图标激活应用
        2. 按 Command+Q 退出
        
        🔄 方法3：活动监视器
        1. 打开 "活动监视器" 应用
        2. 找到对应的进程
        3. 选中后点击 "强制退出"
        
        💡 提示：退出后，菜单栏空间将立即释放，你的新应用就能显示了！
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "📚 打开活动监视器")
        alert.addButton(withTitle: "我知道了")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.launchApplication(
                withBundleIdentifier: "com.apple.ActivityMonitor",
                options: [.async],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
        }
    }
    
    private func showDetailedMenuBarTutorial() {
        let alert = NSAlert()
        alert.messageText = "📚 菜单栏管理完整教程"
        alert.informativeText = """
        🎯 解决菜单栏空间不足的完整方案：
        
        📍 立即解决（推荐）：
        1. 按住 Command 键 (⌘)
        2. 拖拽菜单栏图标重新排序
        3. 将重要应用（如 ClashX）拖到左边
        4. 将不常用应用拖到右边
        
        📍 长期管理：
        • 定期检查菜单栏应用设置
        • 在应用偏好设置中关闭不必要的菜单栏图标
        • 使用专业工具如 Bartender（付费）
        
        📍 应急方案：
        • 重启需要显示的应用（如 ClashX）
        • 暂时退出不重要的菜单栏应用
        • 调整屏幕分辨率增加菜单栏空间
        
        💡 技巧：macOS 会自动隐藏菜单栏右侧溢出的图标，
        通过 Command+拖拽可以有效管理显示优先级！
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "我知道了")
        alert.runModal()
    }
    
    private func handleSpecialApps(app: NSRunningApplication, bundleId: String) {
        // 为特定应用提供专门的处理方式
        if bundleId.lowercased().contains("ollama") {
            print("📍 [特殊应用] 检测到 Ollama，尝试打开管理界面")
            if let url = URL(string: "http://localhost:11434") {
                NSWorkspace.shared.open(url)
            }
        } else if bundleId.lowercased().contains("clashx") {
            print("📍 [特殊应用] 检测到 ClashX，尝试显示")
            // ClashX 通常有右键菜单，尝试激活
            app.activate()
        } else if bundleId.lowercased().contains("docker") {
            print("📍 [特殊应用] 检测到 Docker，尝试激活")
            app.activate()
        }
    }
    
    private func sendShowAllMenuBarItemsEvent() {
        // 模拟按住 Option 键点击菜单栏的操作，这会显示所有隐藏的菜单栏图标
        let script = """
        tell application "System Events"
            key down option
            delay 0.2
            try
                click at {1200, 10}
            end try
            delay 0.1
            key up option
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            
            if let error = errorInfo {
                print("⚠️ AppleScript 执行失败: \(error)")
            } else {
                print("✅ 已发送显示所有菜单栏图标的事件")
            }
        }
    }
    
    // 改进的应用过滤逻辑 - 更精确地过滤菜单栏应用
    private func getRealMenuBarApps() -> [NSRunningApplication] {
        let allApps = NSWorkspace.shared.runningApplications
        
        // 扩展排除列表 - 更全面的过滤
        let excludedApps = [
            "com.menubarmanager.app", "MenuBarManager",
            
            // 浏览器
            "com.google.Chrome", "com.mozilla.firefox", "com.microsoft.edgemac", "com.apple.Safari",
            
            // 输入法相关
            "com.sogou.inputmethod", "com.baidu.inputmethod", "com.tencent.inputmethod",
            "com.iflytek.inputmethod", "com.microsoft.inputmethod",
            
            // 微信相关
            "com.tencent.xinWeChat", "com.tencent.WeWorkMac", "com.wechat.wechat",
            
            // 常见的不需要管理的应用
            "com.adobe.acc.installer", "com.adobe.CCLibrary", 
            "com.microsoft.OneDrive", "com.dropbox.Dropbox",
            "com.spotify.client", "com.apple.Music",
            "com.apple.MobileSMS", "com.apple.FaceTime",
            
            // Xcode 相关
            "com.apple.dt.Xcode", "com.apple.simulator",
            
            // 系统工具
            "com.apple.ActivityMonitor", "com.apple.Console"
        ]
        
        // 扩展的助手应用模式
        let helperPatterns = [
            "helper", "Helper", "renderer", "Renderer", "agent", "Agent",
            "service", "Service", "daemon", "Daemon", "monitor", "Monitor",
            "extension", "Extension", "plugin", "Plugin", "updater", "Updater",
            "launcher", "Launcher", "notifier", "Notifier", "sync", "Sync",
            "installer", "Installer", "uninstaller", "Uninstaller",
            "小程序", "小助手", "助手", "输入法", "InputMethod"
        ]
        
        // 重要应用例外（即使包含 helper 词汇也要显示）
        let importantApps = [
            "postgres", "docker", "database", "server", "mysql", "redis", "mongodb", 
            "ollama", "nginx", "apache", "node", "python", "java", "git"
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
            
            // 检查是否为重要应用
            let isImportantApp = importantApps.contains { important in
                bundleName.lowercased().contains(important) || bundleId.lowercased().contains(important)
            }
            
            // 检查是否为助手应用
            let isHelperApp = helperPatterns.contains { pattern in
                bundleName.lowercased().contains(pattern.lowercased()) ||
                bundleId.lowercased().contains(pattern.lowercased())
            }
            
            // 如果是助手应用但不是重要应用，则跳过
            if isHelperApp && !isImportantApp {
                print("🔧 跳过助手应用: \(bundleName) (bundleId: \(bundleId))")
                return false
            }
            
            // 只包含 accessory 应用（真正的菜单栏应用）
            let isAccessoryApp = app.activationPolicy == .accessory
            
            // 必须是运行中且有有效的 bundle URL
            let isNotHidden = !app.isHidden
            let hasBundleURL = app.bundleURL != nil
            
            // 额外检查：应用必须有图标（这通常表示它是一个真正的用户应用）
            let hasIcon = app.icon != nil
            
            let shouldInclude = isAccessoryApp && isNotHidden && hasBundleURL && hasIcon
            
            if shouldInclude {
                print("✅ 包含菜单栏应用: \(bundleName) (bundleId: \(bundleId))")
            } else {
                print("❌ 排除应用: \(bundleName) - 策略: \(app.activationPolicy.rawValue), 隐藏: \(app.isHidden), 有图标: \(hasIcon)")
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
        
        print("🔍 找到 \(uniqueApps.count) 个真实的菜单栏应用")
        
        // 尝试按照菜单栏中的实际顺序排序
        return sortAppsByMenuBarOrder(uniqueApps)
    }
    
    // 尝试按照菜单栏顺序排序应用
    private func sortAppsByMenuBarOrder(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
        // 由于 macOS 没有直接 API 获取菜单栏图标顺序，我们使用一些启发式方法
        
        // 方法1: 按应用启动时间排序（通常较早启动的在左边）
        let sortedByLaunchDate = apps.sorted { app1, app2 in
            guard let date1 = app1.launchDate, let date2 = app2.launchDate else {
                return (app1.localizedName ?? "") < (app2.localizedName ?? "")
            }
            return date1 < date2
        }
        
        // 方法2: 特定的优先级排序（一些应用通常在特定位置）
        let priorityApps = [
            "Bartender", "Hidden Bar", "CleanMyMac", "1Blocker", "AdGuard",
            "Proxyman", "Charles", "ClashX", "Surge", "ShadowsocksX",
            "Docker", "Postgres", "Redis", "MongoDB", "Ollama",
            "Battery Health", "iStat Menus", "MenuMeters", "System Preferences"
        ]
        
        let finalSorted = sortedByLaunchDate.sorted { app1, app2 in
            let name1 = app1.localizedName ?? ""
            let name2 = app2.localizedName ?? ""
            
            // 检查是否在优先级列表中
            let priority1 = priorityApps.firstIndex(where: { name1.lowercased().contains($0.lowercased()) }) ?? Int.max
            let priority2 = priorityApps.firstIndex(where: { name2.lowercased().contains($0.lowercased()) }) ?? Int.max
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // 如果都不在优先级列表中，保持启动时间顺序
            guard let date1 = app1.launchDate, let date2 = app2.launchDate else {
                return name1 < name2
            }
            return date1 < date2
        }
        
        print("📋 应用排序完成，顺序：")
        for (index, app) in finalSorted.enumerated() {
            print("   \(index + 1). \(app.localizedName ?? "未知") (启动时间: \(app.launchDate?.description ?? "未知"))")
        }
        
        return finalSorted
    }
}

// MARK: - DraggableAppRowDelegate

extension MenuBarAppManagerWindow: DraggableAppRowDelegate {
    func appRowDidStartDrag(_ row: DraggableAppRowView) {
        print("🔄 开始拖拽应用: \(row.app?.localizedName ?? "未知")")
        
        // 可以在这里添加视觉反馈
        row.layer?.opacity = 0.7
    }
    
    func appRowDidEndDrag(_ row: DraggableAppRowView, at point: NSPoint) {
        print("🔄 结束拖拽应用: \(row.app?.localizedName ?? "未知")")
        
        // 恢复透明度
        row.layer?.opacity = 1.0
    }
    
    func shouldAcceptDrop(from source: DraggableAppRowView, to target: DraggableAppRowView) -> Bool {
        // 不能拖拽到自己
        return source != target
    }
    
    func performDrop(from source: DraggableAppRowView, to target: DraggableAppRowView) {
        guard let sourceApp = source.app,
              let targetApp = target.app else { return }
        
        print("🔄 执行拖拽排序: \(sourceApp.localizedName ?? "未知") -> \(targetApp.localizedName ?? "未知")")
        
        // 更新内部应用数组的顺序
        reorderApps(source: sourceApp, target: targetApp)
        
        // 刷新界面
        DispatchQueue.main.async {
            self.loadMenuBarApps()
        }
        
        // 显示排序提示
        showOrderingInstructions(sourceApp: sourceApp, targetApp: targetApp)
    }
    
    private func reorderApps(source: NSRunningApplication, target: NSRunningApplication) {
        guard let sourceIndex = menuBarApps.firstIndex(of: source),
              let targetIndex = menuBarApps.firstIndex(of: target) else { return }
        
        // 移动应用到新位置
        let movedApp = menuBarApps.remove(at: sourceIndex)
        menuBarApps.insert(movedApp, at: targetIndex)
        
        print("📋 应用排序已更新:")
        for (index, app) in menuBarApps.enumerated() {
            print("   \(index + 1). \(app.localizedName ?? "未知")")
        }
    }
    
    private func showOrderingInstructions(sourceApp: NSRunningApplication, targetApp: NSRunningApplication) {
        let alert = NSAlert()
        alert.messageText = "📍 排序提示"
        alert.informativeText = """
        界面中的排序已更新！
        
        要在实际菜单栏中应用此排序：
        
        1️⃣ 按住 Command 键 (⌘)
        2️⃣ 在菜单栏中拖拽 "\(sourceApp.localizedName ?? "应用")" 图标
        3️⃣ 将其拖拽到 "\(targetApp.localizedName ?? "目标位置")" 附近
        4️⃣ 释放鼠标完成排序
        
        💡 提示：你可以参考这个界面中的顺序来手动调整菜单栏图标的位置！
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "我知道了")
        alert.addButton(withTitle: "查看完整教程")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            showTutorial()
        }
    }
}