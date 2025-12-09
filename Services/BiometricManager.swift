import Foundation
import LocalAuthentication
import Security

// MARK: - Biometric Manager
/// Face ID / Touch ID authentication manager with Keychain storage
@MainActor
final class BiometricManager: ObservableObject {
    static let shared = BiometricManager()

    // MARK: - Published Properties
    @Published var isBiometricEnabled: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var isLocked: Bool = false
    @Published var autoLockInterval: AutoLockInterval = .oneMinute

    // MARK: - Types
    enum BiometricType {
        case faceID
        case touchID
        case none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "Biometric"
            }
        }

        var iconName: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .none: return "lock.shield"
            }
        }
    }

    enum AutoLockInterval: String, CaseIterable {
        case fifteenSeconds = "15 sec"
        case thirtySeconds = "30 sec"
        case oneMinute = "1 min"
        case fiveMinutes = "5 min"

        var seconds: TimeInterval {
            switch self {
            case .fifteenSeconds: return 15
            case .thirtySeconds: return 30
            case .oneMinute: return 60
            case .fiveMinutes: return 300
            }
        }
    }

    // MARK: - Private Properties
    private let context = LAContext()
    private let keychainKey = "BiometricEnabled"
    private let autoLockKey = "AutoLockInterval"
    private var backgroundDate: Date?

    // MARK: - Initialization
    private init() {
        loadSettings()
        checkBiometricType()
        setupBackgroundObservers()
    }

    // MARK: - Public Methods

    /// Check if device supports biometric authentication
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error)
        return canEvaluate
    }

    /// Enable biometric authentication
    func enableBiometric() async -> Bool {
        guard isBiometricAvailable() else { return false }

        let success = await authenticate(
            reason: "Enable \(biometricType.displayName) to protect your portfolio")

        if success {
            isBiometricEnabled = true
            saveBiometricEnabled(true)
        }

        return success
    }

    /// Disable biometric authentication
    func disableBiometric() {
        isBiometricEnabled = false
        saveBiometricEnabled(false)
    }

    /// Authenticate using biometrics
    func authenticate(reason: String = "Authenticate to access your portfolio") async -> Bool {
        guard isBiometricAvailable() else { return false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                await MainActor.run {
                    isLocked = false
                }
            }

            return success
        } catch {
            print("❌ Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Lock the app manually
    func forceLock() {
        isLocked = true
    }

    /// Unlock the app
    func unlock() async -> Bool {
        guard isBiometricEnabled else {
            isLocked = false
            return true
        }

        let success = await authenticate()
        if success {
            isLocked = false
        }
        return success
    }

    /// Set auto-lock interval
    func setAutoLockInterval(_ interval: AutoLockInterval) {
        autoLockInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: autoLockKey)
    }

    // MARK: - Private Methods

    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
            biometricType = .none
            return
        }

        switch context.biometryType {
        case .faceID:
            biometricType = .faceID
        case .touchID:
            biometricType = .touchID
        default:
            biometricType = .none
        }
    }

    private func loadSettings() {
        isBiometricEnabled = loadBiometricEnabled()

        if let intervalString = UserDefaults.standard.string(forKey: autoLockKey),
            let interval = AutoLockInterval(rawValue: intervalString)
        {
            autoLockInterval = interval
        }

        // Start locked if biometric is enabled
        if isBiometricEnabled {
            isLocked = true
        }
    }

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.backgroundDate = Date()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            if self.isBiometricEnabled,
                let backgroundDate = self.backgroundDate
            {
                let elapsed = Date().timeIntervalSince(backgroundDate)
                if elapsed >= self.autoLockInterval.seconds {
                    Task { @MainActor in
                        self.isLocked = true
                    }
                }
            }
        }
    }

    // MARK: - Keychain Storage

    private func saveBiometricEnabled(_ enabled: Bool) {
        let data = Data([enabled ? 1 : 0])

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("❌ Failed to save biometric setting to Keychain: \(status)")
        }
    }

    private func loadBiometricEnabled() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
            let data = result as? Data,
            let firstByte = data.first
        {
            return firstByte == 1
        }

        return false
    }
}
