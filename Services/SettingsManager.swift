import Combine
import Foundation
import LocalAuthentication
import SwiftUI
import UserNotifications

// MARK: - Settings Displayable Protocol
protocol SettingsDisplayable {
    var displayName: String { get }
}

// MARK: - Settings Manager
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Published Settings
    @Published var isDarkMode: Bool
    @Published var language: Language
    @Published var currencyDisplay: CurrencyDisplay
    @Published var autoSave: Bool
    @Published var priceAlerts: Bool
    @Published var portfolioUpdates: Bool
    @Published var pushNotifications: Bool
    @Published var dataMasking: Bool
    @Published var biometricLock: Bool
    @Published var autoLockTimer: AutoLockTimer
    @Published var exportFormat: ExportFormat
    @Published var backupFrequency: BackupFrequency

    // MARK: - Enums

    enum Language: String, CaseIterable, SettingsDisplayable {
        case english = "en"
        // case turkish = "tr" // Removed

        var displayName: String {
            switch self {
            case .english: return "English"
            // case .turkish: return "Türkçe"
            }
        }
    }

    enum CurrencyDisplay: String, CaseIterable, SettingsDisplayable {
        case usd = "USD"
        case eur = "EUR"
        // case turkishLira = "TRY" // Removed

        var displayName: String {
            switch self {
            case .usd: return "US Dollar ($)"
            case .eur: return "Euro (€)"
            // case .turkishLira: return "Turkish Lira (₺)"
            }
        }
    }

    enum AutoLockTimer: String, CaseIterable, SettingsDisplayable {
        case immediate = "immediate"
        case oneMinute = "1m"
        case fiveMinutes = "5m"
        case fifteenMinutes = "15m"
        case thirtyMinutes = "30m"
        case oneHour = "1h"
        case never = "never"

        var displayName: String {
            switch self {
            case .immediate: return "Immediate"
            case .oneMinute: return "1 Minute"
            case .fiveMinutes: return "5 Minutes"
            case .fifteenMinutes: return "15 Minutes"
            case .thirtyMinutes: return "30 Minutes"
            case .oneHour: return "1 Hour"
            case .never: return "Never"
            }
        }
    }

    enum ExportFormat: String, CaseIterable, SettingsDisplayable {
        case pdf = "pdf"
        case csv = "csv"
        case excel = "excel"

        var displayName: String {
            switch self {
            case .pdf: return "PDF"
            case .csv: return "CSV"
            case .excel: return "Excel"
            }
        }
    }

    enum BackupFrequency: String, CaseIterable, SettingsDisplayable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case manual = "manual"

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .manual: return "Manual"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        // Load settings from UserDefaults - Default to light mode
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? false
        self.language =
            Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "en") ?? .english
        self.currencyDisplay =
            CurrencyDisplay(
                rawValue: UserDefaults.standard.string(forKey: "currencyDisplay") ?? "USD") ?? .usd
        self.autoSave = UserDefaults.standard.bool(forKey: "autoSave")
        self.priceAlerts = UserDefaults.standard.bool(forKey: "priceAlerts")
        self.portfolioUpdates = UserDefaults.standard.bool(forKey: "portfolioUpdates")
        self.pushNotifications = UserDefaults.standard.bool(forKey: "pushNotifications")
        self.dataMasking = UserDefaults.standard.bool(forKey: "dataMasking")
        self.biometricLock = UserDefaults.standard.bool(forKey: "biometricLock")
        self.autoLockTimer =
            AutoLockTimer(rawValue: UserDefaults.standard.string(forKey: "autoLockTimer") ?? "5m")
            ?? .fiveMinutes
        self.exportFormat =
            ExportFormat(rawValue: UserDefaults.standard.string(forKey: "exportFormat") ?? "pdf")
            ?? .pdf
        self.backupFrequency =
            BackupFrequency(
                rawValue: UserDefaults.standard.string(forKey: "backupFrequency") ?? "weekly")
            ?? .weekly
    }

    // MARK: - Save Methods
    private func saveSetting<T>(_ value: T, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func updateLanguage(_ language: Language) {
        self.language = language
        saveSetting(language.rawValue, forKey: "language")
    }

    func updateCurrencyDisplay(_ currency: CurrencyDisplay) {
        currencyDisplay = currency
        saveSetting(currency.rawValue, forKey: "currencyDisplay")
    }

    func updateAutoSave(_ enabled: Bool) {
        autoSave = enabled
        saveSetting(enabled, forKey: "autoSave")
    }

    func updatePriceAlerts(_ enabled: Bool) {
        priceAlerts = enabled
        saveSetting(enabled, forKey: "priceAlerts")
        if enabled {
            requestNotificationPermission()
        }
    }

    func updatePortfolioUpdates(_ enabled: Bool) {
        portfolioUpdates = enabled
        saveSetting(enabled, forKey: "portfolioUpdates")
    }

    func updatePushNotifications(_ enabled: Bool) {
        pushNotifications = enabled
        saveSetting(enabled, forKey: "pushNotifications")
        if enabled {
            requestNotificationPermission()
        }
    }

    func updateDataMasking(_ enabled: Bool) {
        dataMasking = enabled
        saveSetting(enabled, forKey: "dataMasking")
    }

    func updateBiometricLock(_ enabled: Bool) {
        biometricLock = enabled
        saveSetting(enabled, forKey: "biometricLock")
        if enabled {
            checkBiometricAvailability()
        }
    }

    func updateAutoLockTimer(_ timer: AutoLockTimer) {
        autoLockTimer = timer
        saveSetting(timer.rawValue, forKey: "autoLockTimer")
    }

    func updateExportFormat(_ format: ExportFormat) {
        exportFormat = format
        saveSetting(format.rawValue, forKey: "exportFormat")
    }

    func updateBackupFrequency(_ frequency: BackupFrequency) {
        backupFrequency = frequency
        saveSetting(frequency.rawValue, forKey: "backupFrequency")
    }

    // MARK: - Biometric Authentication
    @discardableResult
    func checkBiometricAvailability() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateWithBiometrics(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        let reason = "Biometric authentication required to access the app"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) {
            success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }
    }

    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
            granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.pushNotifications = false
                    self.priceAlerts = false
                }
            }
        }
    }

    func schedulePriceAlert(for asset: String, targetPrice: Double, isAbove: Bool) {
        guard priceAlerts else { return }

        let content = UNMutableNotificationContent()
        content.title = "Price Alert"
        content.body =
            "\(asset) price is \(isAbove ? "above" : "below") target: $\(String(format: "%.2f", targetPrice))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "price_alert_\(asset)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
