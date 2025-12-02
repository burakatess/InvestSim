import Foundation
import Supabase

/// Kullanıcı profil senkronizasyon servisi
/// Supabase Auth ve local database arasında kullanıcı verilerini senkronize eder
@MainActor
final class UserProfileService {
    static let shared = UserProfileService()

    private let supabase = SupabaseAuthService.shared

    private var client: SupabaseClient {
        return supabase.client
    }

    private init() {}

    // MARK: - Profile Sync

    /// Kullanıcı profilini Supabase'den çek ve local User modeline dönüştür
    /// - Returns: User modeli
    func fetchUserProfile() async throws -> User {
        guard let authUser = supabase.currentAuthUser else {
            throw ProfileError.noAuthenticatedUser
        }

        // Supabase'deki users tablosundan profil bilgilerini çek
        let profile: UserProfile =
            try await client
            .from("users")
            .select()
            .eq("id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        // User modeline dönüştür
        return User(
            id: profile.id,
            email: profile.email,
            name: profile.name,
            profileImageURL: profile.avatarUrl,
            subscriptionPlan: SubscriptionPlan(rawValue: profile.subscriptionPlan) ?? .free,
            isGuest: profile.isGuest
        )
    }

    /// Kullanıcı profilini oluştur veya güncelle
    /// - Parameter user: User modeli
    func upsertUserProfile(_ user: User) async throws {
        let profile = UserProfile(
            id: user.id,
            email: user.email,
            name: user.name,
            avatarUrl: user.profileImageURL,
            subscriptionPlan: user.subscriptionPlan.rawValue,
            isGuest: user.isGuest
        )

        try await client
            .from("users")
            .upsert(profile)
            .execute()
    }

    /// Kullanıcı adını güncelle
    /// - Parameter name: Yeni isim
    func updateUserName(_ name: String) async throws {
        guard let userId = supabase.currentAuthUser?.id.uuidString else {
            throw ProfileError.noAuthenticatedUser
        }

        try await client
            .from("users")
            .update(["name": name])
            .eq("id", value: userId)
            .execute()
    }

    /// Abonelik planını güncelle
    /// - Parameter plan: Yeni abonelik planı
    func updateSubscriptionPlan(_ plan: SubscriptionPlan) async throws {
        guard let userId = supabase.currentAuthUser?.id.uuidString else {
            throw ProfileError.noAuthenticatedUser
        }

        try await client
            .from("users")
            .update(["subscription_plan": plan.rawValue])
            .eq("id", value: userId)
            .execute()
    }

    /// Misafir kullanıcıyı normal kullanıcıya dönüştür
    func convertGuestToUser() async throws {
        guard let userId = supabase.currentAuthUser?.id.uuidString else {
            throw ProfileError.noAuthenticatedUser
        }

        try await client
            .from("users")
            .update(["is_guest": false])
            .eq("id", value: userId)
            .execute()
    }
}

// MARK: - Models

/// Supabase users tablosu için model
struct UserProfile: Codable {
    let id: String
    let email: String
    let name: String?
    let avatarUrl: String?
    let subscriptionPlan: String
    let isGuest: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case avatarUrl = "avatar_url"
        case subscriptionPlan = "subscription_plan"
        case isGuest = "is_guest"
    }
}

// MARK: - Errors

enum ProfileError: LocalizedError {
    case noAuthenticatedUser
    case noActiveSession
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Kimliği doğrulanmış kullanıcı bulunamadı"
        case .noActiveSession:
            return "Aktif oturum bulunamadı"
        case .profileNotFound:
            return "Kullanıcı profili bulunamadı"
        }
    }
}
