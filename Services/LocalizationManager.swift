import Combine
import Foundation
import SwiftUI

// MARK: - Localization Manager
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: SettingsManager.Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            updateBundle()
        }
    }

    private var bundle: Bundle = Bundle.main

    private init() {
        // Load saved language or default to Turkish
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        self.currentLanguage = SettingsManager.Language(rawValue: savedLanguage) ?? .english
        updateBundle()
    }

    // MARK: - Public Methods

    func localizedString(_ key: String, comment: String = "") -> String {
        let result = NSLocalizedString(key, bundle: bundle, comment: comment)
        // Debug: Eğer key ile aynı sonuç dönüyorsa localization çalışmıyor
        if result == key {
            print("⚠️ Localization failed for key: \(key), bundle: \(bundle.bundlePath)")
        }
        return result
    }

    func changeLanguage(_ language: SettingsManager.Language) {
        currentLanguage = language
        // Notify SettingsManager about language change
        SettingsManager.shared.updateLanguage(language)
        // Trigger UI update
        objectWillChange.send()
    }

    // MARK: - Private Methods

    private func updateBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            // Fallback to main bundle if localization files not found
            print("⚠️ Localization bundle not found for language: \(currentLanguage.rawValue)")
            print(
                "Available bundles: \(Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil))"
            )
            self.bundle = Bundle.main
            return
        }
        print("✅ Localization bundle loaded: \(bundle.bundlePath)")
        self.bundle = bundle
    }
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
}

// MARK: - Localization Keys
struct LocalizationKeys {
    // MARK: - Common
    static let ok = "ok"
    static let cancel = "cancel"
    static let save = "save"
    static let delete = "delete"
    static let edit = "edit"
    static let done = "done"
    static let close = "close"
    static let settings = "settings"
    static let portfolio = "portfolio"
    static let plans = "plans"
    static let scenarios = "scenarios"
    static let community = "community"
    static let markets = "markets"

    // MARK: - Settings
    static let appearance = "appearance"
    static let darkMode = "dark_mode"
    static let darkModeDescription = "dark_mode_description"
    static let language = "language"
    static let languageDescription = "language_description"
    static let portfolioSettings = "portfolio_settings"
    static let currency = "currency"
    static let currencyDescription = "currency_description"
    static let autoSave = "auto_save"
    static let autoSaveDescription = "auto_save_description"
    static let notifications = "notifications"
    static let priceAlerts = "price_alerts"
    static let priceAlertsDescription = "price_alerts_description"
    static let portfolioUpdates = "portfolio_updates"
    static let portfolioUpdatesDescription = "portfolio_updates_description"
    static let pushNotifications = "push_notifications"
    static let pushNotificationsDescription = "push_notifications_description"
    static let securityPrivacy = "security_privacy"
    static let dataMasking = "data_masking"
    static let dataMaskingDescription = "data_masking_description"
    static let biometricLock = "biometric_lock"
    static let biometricLockDescription = "biometric_lock_description"
    static let autoLock = "auto_lock"
    static let autoLockDescription = "auto_lock_description"
    static let exportBackup = "export_backup"
    static let export = "export"
    static let backup = "backup"
    static let about = "about"
    static let version = "version"
    static let support = "support"
    static let termsOfService = "terms_of_service"
    static let privacyPolicy = "privacy_policy"

    // MARK: - Dashboard
    static let totalValue = "total_value"
    static let totalGain = "total_gain"
    static let volatility = "volatility"
    static let assets = "assets"
    static let transactions = "transactions"
    static let buyAsset = "buy_asset"
    static let sellAsset = "sell_asset"
    static let addAsset = "add_asset"
    static let searchAssets = "search_assets"
    static let sortBy = "sort_by"
    static let filter = "filter"
    static let noAssets = "no_assets"
    static let noAssetsDescription = "no_assets_description"
    static let portfolioValue = "portfolio_value"
    static let totalGainPercent = "total_gain_percent"
    static let assetCount = "asset_count"
    static let valueHighToLow = "value_high_to_low"
    static let valueLowToHigh = "value_low_to_high"
    static let nameAToZ = "name_a_to_z"
    static let nameZToA = "name_z_to_a"
    static let profitHighToLow = "profit_high_to_low"
    static let profitLowToHigh = "profit_low_to_high"
    static let overview = "overview"
    static let allocation = "allocation"
    static let performance = "performance"
    static let history = "history"
    static let trades = "trades"
    static let addFirstAsset = "add_first_asset"
    static let loading = "loading"
    static let error = "error"
    static let retry = "retry"
    static let refresh = "refresh"
    static let lastUpdate = "last_update"
    static let connectionStatus = "connection_status"
    static let connected = "connected"
    static let disconnected = "disconnected"
    static let connecting = "connecting"
    static let all = "all"
    static let buy = "buy"
    static let sell = "sell"
    static let today = "today"
    static let thisWeek = "this_week"
    static let thisMonth = "this_month"
    static let earn = "earn"

    // MARK: - Asset Management
    static let assetName = "asset_name"
    static let quantity = "quantity"
    static let unitPrice = "unit_price"
    static let totalPrice = "total_price"
    static let purchaseDate = "purchase_date"
    static let currentPrice = "current_price"
    static let currentValue = "current_value"
    static let priceChange = "price_change"
    static let priceChangePercent = "price_change_percent"

    // MARK: - Languages
    static let turkish = "turkish"
    static let english = "english"

    // MARK: - Currencies
    static let turkishLira = "turkish_lira"
    static let usDollar = "us_dollar"
    static let euro = "euro"

    // MARK: - Auto Lock Timer
    static let immediate = "immediate"
    static let oneMinute = "one_minute"
    static let fiveMinutes = "five_minutes"
    static let fifteenMinutes = "fifteen_minutes"
    static let thirtyMinutes = "thirty_minutes"
    static let oneHour = "one_hour"

    // MARK: - Export Formats
    static let pdf = "pdf"
    static let csv = "csv"
    static let excel = "excel"

    // MARK: - Backup Frequency
    static let daily = "daily"
    static let weekly = "weekly"
    static let monthly = "monthly"
}
