import Combine
import Foundation
import UserNotifications

final class NotificationService {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
            _, _ in
        }
    }

    func scheduleDCAReminder(on date: Date, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "DCA Reminder"
        content.body = message
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let req = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func scheduleProfitAlert(thresholdROI: Decimal) {
        // Placeholder: business logic to check ROI externally and schedule here
    }
}
