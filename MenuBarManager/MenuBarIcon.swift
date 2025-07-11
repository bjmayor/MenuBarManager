import Cocoa

class MenuBarIcon {
    let identifier: String
    let title: String
    let image: NSImage?
    let isVisible: Bool
    let position: Int
    
    init(identifier: String, title: String, image: NSImage?, isVisible: Bool, position: Int) {
        self.identifier = identifier
        self.title = title
        self.image = image
        self.isVisible = isVisible
        self.position = position
    }
}

extension MenuBarIcon: Equatable {
    static func == (lhs: MenuBarIcon, rhs: MenuBarIcon) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension MenuBarIcon: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}