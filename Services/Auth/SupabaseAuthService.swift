import Auth
import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

/// Supabase Auth servisi - Tüm kimlik doğrulama işlemlerini yönetir
@MainActor
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private(set) var client: SupabaseClient!

    // MARK: - Initialization

    private init() {
        initializeSupabase()
    }

    private func initializeSupabase() {
        // 1. Environment variables
        // 2. Info.plist
        // 3. Hardcoded fallback (to prevent runtime crashes if Info.plist fails)

        let supabaseURL =
            ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
            ?? "https://hplmwcjyfzjghijdqypa.supabase.co"

        let supabaseAnonKey =
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)
            ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"

        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )

        print("✅ Supabase Auth initialized")

        // Auth state değişikliklerini dinle
        Task {
            await listenToAuthStateChanges()
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthStateChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession:
                if let session = session {
                    print("📱 Initial session: \(session.user.id)")
                }
            case .signedIn:
                if let session = session {
                    print("✅ User signed in: \(session.user.id)")
                }
            case .signedOut:
                print("👋 User signed out")
            case .tokenRefreshed:
                if let session = session {
                    print("🔄 Token refreshed: \(session.user.id)")
                }
            case .userUpdated:
                if let session = session {
                    print("📝 User updated: \(session.user.id)")
                }
            case .userDeleted:
                print("🗑️ User deleted")
            case .mfaChallengeVerified:
                print("🔐 MFA challenge verified")
            case .passwordRecovery:
                print("🔑 Password recovery")
            @unknown default:
                print("⚠️ Unknown auth event")
            }
        }
    }

    // MARK: - Google Sign-In

    /// Google OAuth ile giriş yap
    /// - Returns: Supabase session
    func signInWithGoogle() async throws -> Session {
        // Google Sign-In SDK'dan ID token alındıktan sonra bu metod çağrılacak
        // Bu metod GoogleSignIn SDK entegrasyonu sonrası güncellenecek
        throw SupabaseAuthError.notImplemented(
            "Google Sign-In requires GoogleSignIn SDK integration")
    }

    /// Google ID token ile Supabase'e giriş yap
    /// - Parameter idToken: Google'dan alınan ID token
    /// - Parameter nonce: Google Sign-In sırasında kullanılan raw nonce (opsiyonel)
    /// - Returns: Supabase session
    func signInWithGoogleToken(_ idToken: String, nonce: String? = nil) async throws -> Session {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                nonce: nonce
            )
        )
        return session
    }

    // MARK: - Apple Sign-In (REMOVED)
    // Apple Sign-In requires paid Apple Developer account - feature disabled

    // MARK: - Anonymous Sign-In (Guest Mode)

    /// Anonim kullanıcı olarak giriş yap (Misafir modu)
    /// - Returns: Supabase session
    func signInAnonymously() async throws -> Session {
        let session = try await client.auth.signInAnonymously()

        // Kullanıcı metadata'sına misafir flag'i ekle
        try await updateUserMetadata(["is_guest": true])

        return session
    }

    // MARK: - Account Linking

    /// Anonim hesabı OAuth provider'a bağla
    /// - Parameter provider: OAuth provider (Google veya Apple)
    func linkAnonymousAccount(to provider: Provider) async throws {
        // Mevcut kullanıcının anonim olup olmadığını kontrol et
        guard let user = client.auth.currentUser,
            user.isAnonymous
        else {
            throw SupabaseAuthError.notAnonymousUser
        }

        // Provider'a göre OAuth flow başlat
        // Bu metod UI'dan tetiklenecek ve OAuth callback'i bekleyecek
        throw SupabaseAuthError.notImplemented("Account linking requires OAuth flow completion")
    }

    // MARK: - Session Management

    /// Mevcut oturumu al
    var currentSession: Session? {
        return client.auth.currentSession
    }

    /// Mevcut kullanıcıyı al (Supabase Auth.User)
    var currentAuthUser: Auth.User? {
        return client.auth.currentUser
    }

    /// Oturumu yenile
    func refreshSession() async throws -> Session {
        let session = try await client.auth.refreshSession()
        return session
    }

    /// Çıkış yap
    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - User Metadata

    /// Kullanıcı metadata'sını güncelle
    private func updateUserMetadata(_ metadata: [String: AnyJSON]) async throws {
        let attributes = UserAttributes(data: metadata)
        try await client.auth.update(user: attributes)
    }

    // MARK: - Helper Methods

    /// Kullanıcının anonim olup olmadığını kontrol et
    var isAnonymousUser: Bool {
        guard let user = currentAuthUser else { return false }
        return user.isAnonymous
    }
}

// MARK: - Errors

enum SupabaseAuthError: LocalizedError {
    case notImplemented(String)
    case notAnonymousUser
    case invalidCredentials
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .notAnonymousUser:
            return "Kullanıcı anonim değil. Sadece misafir kullanıcılar hesap bağlayabilir."
        case .invalidCredentials:
            return "Geçersiz kimlik bilgileri"
        case .sessionExpired:
            return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        }
    }
}

// MARK: - Extensions

extension Auth.User {
    /// Kullanıcının anonim olup olmadığını kontrol et
    var isAnonymous: Bool {
        // Supabase'de anonim kullanıcılar için email yoktur
        return email == nil || (email?.isEmpty ?? true)
    }
}
