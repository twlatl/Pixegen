import AppKit
import SwiftUI

/// The small triangle in a tool button's lower right corner, saying that holding the button shows more tools.
struct ToolFlyoutCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 0))
            path.addLine(to: CGPoint(x: 5, y: 5))
            path.addLine(to: CGPoint(x: 0, y: 5))
            path.closeSubpath()
        }
        .fill(.secondary)
        .frame(width: 5, height: 5)
        .accessibilityHidden(true)
    }
}

/// The Shape tool's flyout: every shape it draws, with the current one checked, as Photoshop lists them.
@MainActor
enum ShapeToolMenu {
    static func show(for session: EditorSession) {
        guard let window = NSApp.keyWindow, let view = window.contentView else { return }
        let menu = NSMenu()
        for kind in ShapeKind.allCases {
            let item = ActionMenuItem(title: kind.toolName) {
                session.cancelShape()
                session.shapeKind = kind
                session.selectTool(.shape)
            }
            item.setIcon(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil))
            item.state = session.tool == .shape && kind == session.shapeKind ? .on : .off
            // Shown, not bound: U picks the tool, Shift-U the next shape.
            item.keyEquivalent = "u"
            item.keyEquivalentModifierMask = []
            menu.addItem(item)
        }
        let location = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        menu.popUp(positioning: nil, at: location, in: view)
    }
}

extension NSImage {
    /// One of the tool rail's drawn icons as a flyout item's image, so the menu shows the icon the rail does. A
    /// template, to take the menu's own color; with room at the top right for the icon's badge.
    @MainActor static func toolMenuIcon(_ icon: some View) -> NSImage? {
        let renderer = ImageRenderer(content: icon.frame(width: 14, height: 14).padding(.top, 2).padding(.horizontal, 3))
        renderer.scale = 2
        let image = renderer.nsImage
        image?.isTemplate = true
        return image
    }
}

/// Covers a tool button so that a click picks the tool, while holding the mouse down (or a right-click) shows its
/// flyout instead. SwiftUI's long-press gesture doesn't reach a button on macOS, so this times the press itself.
struct PressAndHold: NSViewRepresentable {
    var click: () -> Void
    var hold: () -> Void

    func makeNSView(context: Context) -> HoldView { HoldView() }
    func updateNSView(_ view: HoldView, context: Context) {
        view.click = click
        view.hold = hold
    }

    final class HoldView: NSView {
        var click: () -> Void = {}
        var hold: () -> Void = {}
        private var timer: Timer?
        private var held = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            held = false
            timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.held = true
                    self.hold()
                }
            }
        }
        override func mouseUp(with event: NSEvent) {
            timer?.invalidate()
            timer = nil
            if !held, bounds.contains(convert(event.locationInWindow, from: nil)) { click() }
        }
        override func rightMouseDown(with event: NSEvent) { hold() }
    }
}

/// A menu item that runs a closure, for menus built in code.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, enabled: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: enabled ? #selector(run) : nil, keyEquivalent: "")
        target = self
        isEnabled = enabled
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func run() { handler() }

    /// Gives the item an icon that shows: from macOS 27 a menu hides its items' images unless they ask to be seen.
    func setIcon(_ icon: NSImage?) {
        image = icon
        if #available(macOS 27.0, *) { preferredImageVisibility = .visible }
    }
}
