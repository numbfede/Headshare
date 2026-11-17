import Foundation
import UserNotifications

enum Notifier {
    private static let delegate = ForegroundDelegate()

    /// UNUserNotificationCenter crashes outside an .app bundle (e.g. running the SwiftPM target from Xcode).
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static func requestAuthorization() {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(title: String, body: String) {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

/// Shows banners even while Headshare is the active app.
private final class ForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
