import Combine
import Foundation
import Supabase

// AssetService - Supabase Integration
// Re-enabled after fixing package dependencies

/// Asset model from Supabase (matches new schema)
struct SupabaseAsset: Codable, Identifiable, Hashable {
    let id: UUID
    let symbol: String  // Primary identifier (was 'code')
    let displayName: String
    let assetClass: String  // crypto, stock, etf, fx, metal
    let currency: String
    let provider: String
    let providerSymbol: String?
    let isActive: Bool

    // Computed property for backward compatibility
    var code: String { symbol }
    var name: String { displayName }

    /// Convert DB asset_class to iOS category
    var category: String {
        switch assetClass.lowercased() {
        case "stock": return "us_stock"
        case "etf": return "us_etf"
        case "fx": return "forex"
        case "metal": return "commodity"
        default: return assetClass  // crypto stays as crypto
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, symbol, currency, provider
        case displayName = "display_name"
        case assetClass = "asset_class"
        case providerSymbol = "provider_symbol"
        case isActive = "is_active"
    }
}

/// Asset service - fetches and manages assets from Supabase
@MainActor
final class AssetService: ObservableObject {
    static let shared = AssetService()

    @Published var assets: [SupabaseAsset] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let supabase: SupabaseClient

    private init() {
        // Initialize Supabase client
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://hplmwcjyfzjghijdqypa.supabase.co")!,
            supabaseKey:
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4",
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    /// Fetch all assets from Supabase
    func fetchAssets() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [SupabaseAsset] =
                try await supabase
                .from("assets")
                .select()
                .eq("is_active", value: true)
                .order("symbol")
                .execute()
                .value

            self.assets = response
            print("✅ Loaded \(response.count) assets from Supabase")
        } catch {
            self.error = error
            print("❌ Failed to load assets: \(error)")
            throw error
        }
    }

    /// Get asset by code
    func getAsset(code: String) -> SupabaseAsset? {
        return assets.first { $0.code.uppercased() == code.uppercased() }
    }

    /// Get all assets (legacy compatibility - returns all active assets)
    func getWebSocketAssets() -> [SupabaseAsset] {
        return assets.filter { $0.isActive }
    }

    /// Get assets by category
    func getAssets(category: String) -> [SupabaseAsset] {
        return assets.filter { $0.category.lowercased() == category.lowercased() }
    }

    /// Get assets by provider
    func getAssets(provider: String) -> [SupabaseAsset] {
        return assets.filter { $0.provider.lowercased() == provider.lowercased() }
    }
}
