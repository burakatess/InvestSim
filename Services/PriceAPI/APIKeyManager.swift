import Foundation
import Security

final class APIKeyManager {
    static let shared = APIKeyManager()

    private init() {}

    // MARK: - API Keys
    private let keys: [String: String] = [
        // Development keys (replace with actual keys or use environment variables)
        "tiingo": ProcessInfo.processInfo.environment["TIINGO_API_KEY"] ?? "",
        "goldapi": ProcessInfo.processInfo.environment["GOLDAPI_KEY"] ?? "",
        "alpaca_key": ProcessInfo.processInfo.environment["ALPACA_API_KEY"] ?? "",
        "alpaca_secret": ProcessInfo.processInfo.environment["ALPACA_API_SECRET"] ?? "",
    ]

    // MARK: - Public Methods
    func getAPIKey(for service: String) -> String? {
        // Try environment variable first
        if let envKey = keys[service], !envKey.isEmpty {
            return envKey
        }

        // Try keychain
        return getFromKeychain(service: service)
    }

    func setAPIKey(_ key: String, for service: String) {
        saveToKeychain(key: key, service: service)
    }

    func removeAPIKey(for service: String) {
        deleteFromKeychain(service: service)
    }

    // MARK: - Keychain Operations
    private func saveToKeychain(key: String, service: String) {
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "InvestSimulator",
            kSecValueData as String: data,
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✅ API key saved for \(service)")
        } else {
            print("❌ Failed to save API key for \(service): \(status)")
        }
    }

    private func getFromKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "InvestSimulator",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return key
    }

    private func deleteFromKeychain(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "InvestSimulator",
        ]

        SecItemDelete(query as CFDictionary)
        print("🗑️ API key deleted for \(service)")
    }
}
