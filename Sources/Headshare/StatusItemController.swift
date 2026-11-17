import AppKit
import Combine
import SwiftUI

/// Menu bar icon + dropdown panel.
/// The panel's size is driven by AppKit itself: an NSHostingController with
/// `.preferredContentSize` makes the window follow the SwiftUI content size exactly,
/// whenever it changes (sharing on/off, sections expanding, devices connecting).
/// We only keep the top edge pinned under the menu bar icon.
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var item: NSStatusItem?
    private var panel: MenuPanel?
    private var controller: NSHostingController<AnyView>?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    var isShown: Bool { panel?.isVisible == true }

    func install() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(toggle(_:))
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        self.item = item

        AppModel.shared.$isSharing
            .receive(on: RunLoop.main)
            .sink { [weak self] sharing in self?.updateIcon(sharing) }
            .store(in: &cancellables)
        updateIcon(AppModel.shared.isSharing)
    }

    // MARK: Show / hide

    @objc private func toggle(_ sender: Any?) {
        isShown ? close() : show()
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        AppModel.shared.refreshDevices()
        AppModel.shared.refreshPaired()

        if let view = controller?.view {
            view.layoutSubtreeIfNeeded()
            panel.setContentSize(view.fittingSize)
        }
        pinUnderIcon()
        panel.orderFrontRegardless()
        panel.makeKey()
        item?.button?.highlight(true)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.isShown == true { self?.close(); return nil } // Esc
            return event
        }
    }

    func close() {
        panel?.orderOut(nil)
        item?.button?.highlight(false)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        keyMonitor = nil
    }

    // MARK: Layout

    /// AppKit resized the panel to the new content size: move it so the top stays under the icon.
    @objc private func panelDidResize(_ notification: Notification) {
        pinUnderIcon()
        panel?.invalidateShadow()
    }

    private func pinUnderIcon() {
        guard let panel, let button = item?.button, let buttonWindow = button.window else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let size = panel.frame.size
        var x = anchor.midX - size.width / 2
        x = max(screen.minX + 6, min(x, screen.maxX - size.width - 6))
        let origin = NSPoint(x: round(x), y: round(anchor.minY - 5 - size.height))
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
    }

    private func makePanel() -> MenuPanel {
        let root = MenuContent()
            .environmentObject(AppModel.shared)
            .fixedSize()
            .background(PanelBackground())
            .clipShape(RoundedRectangle(cornerRadius: PanelBackground.cornerRadius, style: .continuous))
        let controller = NSHostingController(rootView: AnyView(root))
        controller.sizingOptions = [.preferredContentSize]  // window follows the content size
        self.controller = controller

        let panel = MenuPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.contentViewController = controller
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = .clear

        NotificationCenter.default.addObserver(self, selector: #selector(panelDidResize(_:)),
                                               name: NSWindow.didResizeNotification, object: panel)
        return panel
    }

    private func updateIcon(_ sharing: Bool) {
        let name = sharing ? "headphones.circle.fill" : "headphones"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Headshare")
        image?.isTemplate = true
        item?.button?.image = image
    }
}

/// Borderless panel that can take key focus (for ⌘Q and Esc) without activating the app.
final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Liquid Glass on macOS 26, the standard menu material before that.
private struct PanelBackground: View {
    static let cornerRadius: CGFloat = 22

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: Self.cornerRadius))
        } else {
            MenuMaterial()
        }
        #else
        MenuMaterial()
        #endif
    }
}

private struct MenuMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
