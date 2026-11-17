import AppKit
import SwiftUI

/// Owns the Settings and Welcome windows. Headshare is a menu bar app, so the Dock icon
/// only appears while one of these windows is open (unless the user asks to always show it).
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func showSettings(tab: SettingsTab? = nil) {
        if let tab { SettingsNavigation.shared.tab = tab }
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(AppModel.shared)
                .environmentObject(SettingsNavigation.shared)
            let window = makeWindow(title: "Headshare Settings", size: NSSize(width: 720, height: 520), resizable: true, content: view)
            window.setFrameAutosaveName("HeadshareSettings")
            settingsWindow = window
        }
        present(settingsWindow!)
    }

    func showOnboarding(restart: Bool = false) {
        if restart, let window = onboardingWindow {
            window.delegate = nil
            window.close()
            onboardingWindow = nil
        }
        if onboardingWindow == nil {
            let view = OnboardingView().environmentObject(AppModel.shared)
            let window = makeWindow(title: "Welcome to Headshare", size: NSSize(width: 900, height: 640), resizable: false, content: view)
            window.titleVisibility = .hidden
            onboardingWindow = window
        }
        present(onboardingWindow!)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    func updateActivationPolicy() {
        let anyVisible = [settingsWindow, onboardingWindow].contains { $0?.isVisible == true }
        NSApp.setActivationPolicy(anyVisible || AppModel.shared.showDockIcon ? .regular : .accessory)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === onboardingWindow {
            AppModel.shared.onboardingCompleted = true
            onboardingWindow = nil
        }
        DispatchQueue.main.async { self.updateActivationPolicy() }
    }

    // MARK: Helpers

    private func makeWindow<V: View>(title: String, size: NSSize, resizable: Bool, content: V) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentViewController = NSHostingController(rootView: content)
        window.setContentSize(size)
        window.center()
        window.delegate = self
        return window
    }

    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
