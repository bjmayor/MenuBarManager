# MenuBarManager

一个 macOS 菜单栏管理工具，用于解决菜单栏图标过多时的溢出问题。当菜单栏图标太多无法完全显示时，本应用会在菜单栏中显示一个管理图标，点击后可以访问所有被隐藏的菜单栏应用。

## 功能特性

- 🎯 **智能检测**：自动检测真正的菜单栏应用（只显示 accessory 类型的应用）
- 📱 **简洁图标**：在菜单栏显示简洁的 ⋯ 图标
- 🔍 **精确过滤**：排除系统应用、浏览器、助手进程等不相关应用
- 🗃️ **重要应用支持**：特别支持 Postgres、Docker、Ollama 等开发工具
- 🔄 **自动刷新**：每5秒自动检测应用变化
- 🚪 **退出功能**：菜单中提供退出选项
- 🤐 **静默运行**：无弹框干扰，后台静默工作

## 截图

![MenuBarManager Screenshot](screenshot.png)

## 安装方法

### 方法1：从 Release 下载
1. 前往 [Releases](https://github.com/bjmayor/MenuBarManager/releases) 页面
2. 下载最新版本的 `MenuBarManager.app`
3. 将应用拖拽到 `应用程序` 文件夹
4. 双击启动应用

### 方法2：源代码编译
1. 克隆仓库：
   ```bash
   git clone git@github.com:bjmayor/MenuBarManager.git
   cd MenuBarManager
   ```

2. 使用 Xcode 打开项目：
   ```bash
   open MenuBarManager.xcodeproj
   ```

3. 在 Xcode 中编译并运行（⌘R）

## 使用方法

1. **启动应用**：双击 MenuBarManager.app 启动应用
2. **查看隐藏应用**：点击菜单栏中的 ⋯ 图标
3. **激活应用**：从下拉菜单中点击任何应用名称来激活它
4. **退出应用**：从菜单底部选择 "退出 MenuBar Manager"

## 实现原理

### 核心架构

MenuBarManager 采用自定义的 NSApplication 子类作为应用主体，通过以下技术实现菜单栏管理：

#### 1. 自定义应用程序类
```swift
@main
class CustomApplication: NSApplication {
    // 继承 NSApplication 并重写 finishLaunching() 方法
    // 在 Info.plist 中设置 NSPrincipalClass = "MenuBarManager.CustomApplication"
}
```

#### 2. 菜单栏图标创建
```swift
// 使用 NSStatusBar.system.statusItem 创建状态栏项目
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.behavior = .removalAllowed  // 允许被移除但优先显示
```

#### 3. 应用检测与过滤

**检测原理**：
- 使用 `NSWorkspace.shared.runningApplications` 获取所有运行的应用
- 通过 `app.activationPolicy == .accessory` 过滤出真正的菜单栏应用
- 排除系统应用（bundle ID 以 `com.apple.` 开头）
- 排除助手进程（名称包含 "helper", "agent", "service" 等）

**特殊处理**：
```swift
// 重要应用白名单（即使是 helper 类型也要显示）
let importantApps = ["postgres", "docker", "database", "server", "mysql", "redis", "mongodb", "ollama"]
```

#### 4. 应用激活机制

支持多种激活方式确保兼容性：
```swift
// 1. 标准激活
app.activate(options: [])

// 2. NSWorkspace 激活  
NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], ...)

// 3. URL 方式打开
NSWorkspace.shared.openApplication(at: bundleURL, configuration: ...)
```

#### 5. 自动刷新机制
```swift
// 每5秒检查应用列表变化
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    DispatchQueue.main.async {
        self.refreshAppListIfNeeded()
    }
}
```

### 技术细节

#### NSStatusItem 优先级策略
- 使用 `NSStatusItem.variableLength` 获得最高显示优先级
- 设置 `behavior = .removalAllowed` 平衡显示优先级和用户控制
- 通过系统自动布局避免与其他菜单栏应用冲突

#### 应用生命周期管理
- **启动**：设置为 `.accessory` 激活策略，不在 Dock 中显示
- **图标管理**：动态更新工具提示显示隐藏应用数量
- **内存优化**：使用弱引用和延迟加载避免内存泄漏

#### 兼容性考虑
- **macOS 版本**：支持 macOS 14.0+
- **架构支持**：原生支持 Apple Silicon (arm64) 和 Intel (x86_64)
- **沙盒兼容**：应用使用必要的权限申请，支持 App Store 分发

## 开发环境要求

- **Xcode**: 15.0+
- **macOS**: 14.0+
- **Swift**: 5.0+

## 项目结构

```
MenuBarManager/
├── MenuBarManager.xcodeproj/          # Xcode 项目文件
├── MenuBarManager/
│   ├── CustomApplication.swift       # 主应用类（核心逻辑）
│   ├── AppDelegate.swift            # 应用委托（已弃用）
│   ├── MenuBarManager.swift         # 旧版管理器（已弃用）
│   ├── MenuBarIcon.swift           # 图标数据模型
│   ├── Info.plist                  # 应用信息配置
│   ├── Assets.xcassets             # 应用资源
│   └── MenuBarManager.entitlements # 权限配置
├── README.md                        # 本文档
└── LICENSE                         # 开源协议
```

## 贡献指南

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -am 'Add some feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 创建 Pull Request

## 许可协议

本项目采用 MIT 许可协议 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 致谢

- 感谢 [Bartender](https://www.macbartender.com/) 和 [Ice](https://github.com/jordanbaird/Ice) 项目的启发
- 感谢 Apple 提供的 NSStatusBar API
- 感谢所有贡献者和用户的反馈

## 更新日志

### v1.0.0 (2025-07-11)
- 🎉 初始版本发布
- ✅ 基础菜单栏管理功能
- ✅ 智能应用检测与过滤
- ✅ 多种应用激活方式
- ✅ 自动刷新机制
- ✅ 退出功能