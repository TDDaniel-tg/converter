import AppKit
import UserNotifications

// MARK: - Notification Manager
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(result: ConversionResult, fileCount: Int) {
        let (title, body): (String, String)

        switch result {
        case .success(let count):
            title = "✅ Zestify — Done!"
            body = count == 1
                ? "1 file converted successfully."
                : "\(count) files converted successfully."

        case .partial(let converted, let failed, let message):
            title = "⚠️ Zestify — Partial"
            let base = "\(converted) converted, \(failed) failed."
            body = message.map { "\(base) \($0)" } ?? base

        case .failure(let error):
            title = "❌ Zestify — Failed"
            body = error
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
