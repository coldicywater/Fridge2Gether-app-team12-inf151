import Foundation
import UserNotifications

/// Local reminders: "Oat milk expires tomorrow". No server or paid Apple account needed.
enum NotificationService {
    private static let prefix = "expiry-"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleExpiryReminders(for foods: [Food]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)

            let calendar = Calendar.current
            for food in foods.prefix(60) {
                // 9 AM the day before it expires.
                guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: food.expiry) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
                components.hour = 9
                guard let fireDate = calendar.date(from: components), fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(food.name) expires tomorrow"
                content.body = "Cook it, or share it with a roommate before it goes to waste."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                center.add(UNNotificationRequest(identifier: prefix + food.id, content: content, trigger: trigger))
            }
        }
    }
}
