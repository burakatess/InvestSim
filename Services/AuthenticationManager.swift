import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import GoogleSignIn
import Supabase
import SwiftUI

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String?
    let profileImageURL: String?
    let subscriptionPlan: SubscriptionPlan
    let isGuest: Bool
    let createdAt: Date
    let lastLoginAt: Date

    init(
        id: String, email: String, name: String? = nil, profileImageURL: String? = nil,
        subscriptionPlan: SubscriptionPlan = .free, isGuest: Bool = false
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.profileImageURL = profileImageURL
        self.subscriptionPlan = subscriptionPlan
        self.isGuest = isGuest
        self.createdAt = Date()
        self.lastLoginAt = Date()
    }

    // Guest user factory
    static func createGuestUser() -> User {
        return User(
            id: "guest_\(UUID().uuidString)",
            email: "guest@local",
            name: "Misafir Kullanıcı",
            subscriptionPlan: .free,
            isGuest: true
        )
    }
}

// MARK: - Subscription Plan
enum SubscriptionPlan: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free:
            return "Ücretsiz Plan"
        case .premium:
            return "Premium Plan"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "5 portföy sınırı",
                "Temel analitik",
                "Günlük fiyat güncellemeleri",
                "CSV export",
            ]
        case .premium:
            return [
                "Sınırsız portföy",
                "Gelişmiş analitik",
                "Gerçek zamanlı fiyatlar",
                "PDF/Excel export",
                "Fiyat uyarıları",
                "Cloud sync",
                "Öncelikli destek",
            ]
        }
    }

    var price: String {
        switch self {
        case .free:
            return "Ücretsiz"
        case .premium:
            return "₺29.99/ay"
        }
    }
}

// MARK: - Authentication State
enum AuthState: Equatable {
    case loading
    case authenticated(User)
    case unauthenticated
    case error(String)
}

// MARK: - Authentication Manager
@MainActor
final class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var latestErrorMessage: String?

    private var currentNonce: String?
    private let userDefaultsKey = "currentUser"
    private let supabaseAuth = SupabaseAuthService.shared
    private let profileService = UserProfileService.shared
    private let onboardingCompletedKey = "hasCompletedOnboarding"

    var isGuest: Bool {
        currentUser?.isGuest ?? false
    }

    private var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey) }
    }

    private override init() {
        super.init()
        checkAuthState()
    }

    // MARK: - Public Methods

    func continueAsGuest() async {
        isLoading = true

        do {
            // Supabase'de anonim kullanıcı oluştur
            let session = try await supabaseAuth.signInAnonymously()

            // User modeline dönüştür
            let guestUser = User(
                id: session.user.id.uuidString,
                email: "guest@local",
                name: "Misafir Kullanıcı",
                subscriptionPlan: .free,
                isGuest: true
            )

            // Profili Supabase'e kaydet
            try await profileService.upsertUserProfile(guestUser)

            currentUser = guestUser
            authState = .authenticated(guestUser)
            saveUserSession(guestUser)
            hasCompletedOnboarding = true
            latestErrorMessage = nil

            // Set light mode for guest user
            UserDefaults.standard.set(false, forKey: "isDarkMode")
            SettingsManager.shared.isDarkMode = false

            print("✅ Guest user created and authenticated with Supabase")
        } catch {
            authState = .unauthenticated
            latestErrorMessage = error.localizedDescription
            print("❌ Guest sign-in failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func signInWithGoogle() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            // Get the presenting view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootViewController = windowScene.windows.first?.rootViewController
            else {
                print("❌ Root view controller not found")
                throw SupabaseAuthError.invalidCredentials
            }

            // Configure Google Sign-In
            let clientID =
                (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String)
                ?? "611362196900-shkufjnfpb4pujmc7rgn90pnhll82o79.apps.googleusercontent.com"

            print("ℹ️ Using Google Client ID: \(clientID)")

            // Önceki oturumdan kalan 'nonce' sorunlarını önlemek için çıkış yap
            GIDSignIn.sharedInstance.signOut()

            // Create nonce
            let rawNonce = randomNonceString()
            let hashedNonce = sha256(rawNonce)

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            // Perform Google Sign-In with nonce
            print("ℹ️ Starting Google Sign-In flow...")
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            )
            print("✅ Google Sign-In successful")

            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ ID Token not found in Google result")
                throw SupabaseAuthError.invalidCredentials
            }
            print("✅ ID Token obtained")

            // Sign in to Supabase with Google token AND nonce
            print("ℹ️ Signing in to Supabase with Google token...")
            let session = try await supabaseAuth.signInWithGoogleToken(idToken, nonce: rawNonce)
            print("✅ Supabase sign-in successful")

            // Create user profile
            let user = User(
                id: session.user.id.uuidString,
                email: session.user.email ?? result.user.profile?.email ?? "unknown@gmail.com",
                name: result.user.profile?.name,
                profileImageURL: result.user.profile?.imageURL(withDimension: 200)?.absoluteString,
                subscriptionPlan: .free,
                isGuest: false
            )

            // Save to Supabase
            try await profileService.upsertUserProfile(user)

            currentUser = user
            authState = .authenticated(user)
            saveUserSession(user)
            hasCompletedOnboarding = true
            latestErrorMessage = nil

            print("✅ Google Sign-In flow completed successfully")
        } catch {
            authState = .unauthenticated
            latestErrorMessage = error.localizedDescription
            print("❌ Google Sign-In failed with error: \(error)")
        }

        isLoading = false
    }

    // Apple Sign-In removed - requires paid Apple Developer account

    func signInWithEmail(email: String, password: String) async {
        isLoading = true

        // Email/Password authentication
        // Bu kısım Firebase Auth entegrasyonu gerektirir
        // Şimdilik mock implementation

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockUser = User(
                id: "email_123",
                email: email,
                name: "Email Kullanıcısı",
                subscriptionPlan: .free
            )

            self.currentUser = mockUser
            self.authState = .authenticated(mockUser)
            self.isLoading = false
            self.saveUserSession(mockUser)
            self.hasCompletedOnboarding = true
            self.latestErrorMessage = nil
        }
    }

    func signUpWithEmail(email: String, password: String, name: String) async {
        isLoading = true

        // Email/Password registration
        // Bu kısım Firebase Auth entegrasyonu gerektirir
        // Şimdilik mock implementation

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockUser = User(
                id: "email_\(UUID().uuidString)",
                email: email,
                name: name,
                subscriptionPlan: .free
            )

            self.currentUser = mockUser
            self.authState = .authenticated(mockUser)
            self.isLoading = false
            self.saveUserSession(mockUser)
            self.hasCompletedOnboarding = true
            self.latestErrorMessage = nil
        }
    }

    func signOut() async {
        do {
            try await supabaseAuth.signOut()
            currentUser = nil
            authState = .unauthenticated
            clearUserSession()
            hasCompletedOnboarding = false
            latestErrorMessage = nil
            print("✅ User signed out successfully")
        } catch {
            latestErrorMessage = error.localizedDescription
            print("❌ Sign out failed: \(error.localizedDescription)")
        }
    }

    func migrateGuestDataToUser(_ user: User) {
        // Migrate guest data to new user account
        // This will be implemented with UserDataManager
        print("Migrating guest data to user: \(user.id)")
    }

    // MARK: - Private Methods

    private func saveUserSession(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDefaultsKey)
        }
    }

    private func loadUserSession() -> User? {
        guard let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
            let user = try? JSONDecoder().decode(User.self, from: userData)
        else {
            return nil
        }
        return user
    }

    private func clearUserSession() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    func upgradeToPremium() async {
        guard let user = currentUser else { return }

        isLoading = true

        // Premium upgrade logic
        // Bu kısım StoreKit entegrasyonu gerektirir
        // Şimdilik mock implementation

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let updatedUser = User(
                id: user.id,
                email: user.email,
                name: user.name,
                profileImageURL: user.profileImageURL,
                subscriptionPlan: .premium
            )

            self.currentUser = updatedUser
            self.authState = .authenticated(updatedUser)
            self.isLoading = false
        }
    }

    // MARK: - Private Methods

    private func checkAuthState() {
        clearUserSession()
        currentUser = nil
        hasCompletedOnboarding = false
        authState = .unauthenticated
        latestErrorMessage = nil
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// Apple Sign-In delegates removed - feature disabled (requires paid Apple Developer account)
