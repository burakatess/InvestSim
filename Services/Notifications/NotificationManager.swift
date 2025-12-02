import Combine
import Foundation
import SwiftUI
import UserNotifications

// MARK: - Notification Scheduling Protocol
protocol NotificationScheduling: AnyObject {
    func requestPermission() async -> Bool
    func scheduleNotification(
        title: String, body: String, identifier: String, trigger: UNNotificationTrigger?)
    func cancelNotification(identifier: String)
    func cancelAllNotifications()
}

// MARK: - Notification Manager
@MainActor
final class NotificationManager: ObservableObject, NotificationScheduling {
    static let shared = NotificationManager()

    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Public Methods

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
                self.updateAuthorizationStatus()
            }
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }

    func scheduleNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        trigger: UNNotificationTrigger? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger ?? UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Notification scheduled: \(identifier)")
            }
        }
    }

    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }

    func getDeliveredNotifications() async -> [UNNotification] {
        return await center.deliveredNotifications()
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    private func updateAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
}

// MARK: - Price Alert Manager
@MainActor
final class PriceAlertManager: ObservableObject {
    static let shared = PriceAlertManager()

    @Published var alerts: [PriceAlert] = []

    private let notificationManager = NotificationManager.shared
    private var priceUpdateTimer: Timer?

    private init() {
        loadAlerts()
        startPriceMonitoring()
    }

    deinit {
        priceUpdateTimer?.invalidate()
        priceUpdateTimer = nil
        print("🧹 PriceAlertManager deinit - Timer temizlendi")
    }

    // MARK: - Public Methods

    func addAlert(_ alert: PriceAlert) {
        alerts.append(alert)
        saveAlerts()
        print("✅ Price alert added: \(alert.asset.rawValue) - \(alert.targetPrice)")
    }

    func removeAlert(_ alert: PriceAlert) {
        alerts.removeAll { $0.id == alert.id }
        saveAlerts()
        print("✅ Price alert removed: \(alert.asset.rawValue)")
    }

    func updatePrice(_ price: Decimal, for asset: AssetCode) {
        let relevantAlerts = alerts.filter { $0.asset == asset }

        for alert in relevantAlerts {
            let shouldTrigger = checkAlertCondition(alert: alert, currentPrice: price)
            if shouldTrigger {
                triggerAlert(alert, currentPrice: price)
            }
        }
    }

    // MARK: - Private Methods

    private func startPriceMonitoring() {
        // This would integrate with your price update system
        // For now, we'll simulate with a timer
        priceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            // This would be called when prices are updated
            // Integration point with your price system
        }
    }

    private func checkAlertCondition(alert: PriceAlert, currentPrice: Decimal) -> Bool {
        switch alert.direction {
        case .above:
            return currentPrice >= alert.targetPrice
        case .below:
            return currentPrice <= alert.targetPrice
        }
    }

    private func triggerAlert(_ alert: PriceAlert, currentPrice: Decimal) {
        let title = "Fiyat Uyarısı"
        let body =
            "\(alert.asset.rawValue) fiyatı \(alert.targetPrice) seviyesine ulaştı. Güncel fiyat: \(currentPrice)"

        notificationManager.scheduleNotification(
            title: title,
            body: body,
            identifier: "price_alert_\(alert.id.uuidString)"
        )

        // Remove the triggered alert
        removeAlert(alert)
    }

    private func loadAlerts() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "priceAlerts"),
            let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data)
        {
            self.alerts = decoded
        }
    }

    private func saveAlerts() {
        if let encoded = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(encoded, forKey: "priceAlerts")
        }
    }
}

// MARK: - Price Alert Model
struct PriceAlert: Identifiable, Codable {
    var id = UUID()
    let asset: AssetCode
    let targetPrice: Decimal
    let direction: AlertDirection
    let createdAt: Date

    init(asset: AssetCode, targetPrice: Decimal, direction: AlertDirection) {
        self.asset = asset
        self.targetPrice = targetPrice
        self.direction = direction
        self.createdAt = Date()
    }
}

enum AlertDirection: String, CaseIterable, Codable {
    case above = "above"
    case below = "below"

    var displayName: String {
        switch self {
        case .above: return "Üzerinde"
        case .below: return "Altında"
        }
    }
}
