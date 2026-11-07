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
        case .success(let outputUrls):
            title = "✅ Zestify — Готово!"
            body = outputUrls.count == 1
                ? "Файл успешно сконвертирован: \(outputUrls[0].lastPathComponent)"
                : "\(outputUrls.count) файлов успешно сконвертировано."

        case .partial(let converted, let failed, let message):
            title = "⚠️ Zestify — Частично"
            let base = "Сконвертировано: \(converted), ошибок: \(failed)."
            body = message.map { "\(base) \($0)" } ?? base

        case .failure(let error):
            title = "❌ Zestify — Ошибка"
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
