import AppKit

// Pure AppKit entry point. The menu bar panel, Settings and Welcome windows are NSWindows
// hosting SwiftUI views; there are no SwiftUI scenes that macOS could open on its own.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.mainMenu = MainMenu.make()
app.run()
