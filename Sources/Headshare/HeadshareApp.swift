import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        if !AppIcon.isBundled, let icon = AppIcon.devIcon { NSApp.applicationIconImage = icon }  // run from Xcode
        StatusItemController.shared.install()
        WindowManager.shared.updateActivationPolicy()
        if !model.onboardingCompleted {
            DispatchQueue.main.async { WindowManager.shared.showOnboarding() }
        }
    }

    /// Opening Headshare again (Finder, Spotlight, Launchpad) while it runs shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Headshare manages its own windows; nothing should come back from a previous session.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }

    // MARK: Menu actions (reached through the responder chain)

    @objc func showSettings(_ sender: Any?) { WindowManager.shared.showSettings() }
    @objc func showAbout(_ sender: Any?) { WindowManager.shared.showSettings(tab: .about) }
}

/// App, Edit and Window menus for when a Headshare window is in front
/// (⌘, Settings, ⌘Q, ⌘W, copy/paste in text fields).
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: String(localized: "About Headshare"), action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: String(localized: "Settings…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        app.addItem(.separator())
        app.addItem(withTitle: String(localized: "Hide Headshare"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: String(localized: "Quit Headshare"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(app, to: main)

        let edit = NSMenu(title: String(localized: "Edit"))
        edit.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(edit, to: main)

        let window = NSMenu(title: String(localized: "Window"))
        window.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(window, to: main)
        NSApp.windowsMenu = window

        return main
    }

    private static func add(_ menu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem()
        item.submenu = menu
        main.addItem(item)
    }
}
