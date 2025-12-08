import Foundation
import Supabase

/// Model for user scenarios stored in Supabase
struct UserScenario: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var frequencyPerMonth: Int
    var monthlyAmount: Decimal
    var currency: String
    var annualIncreasePercent: Decimal
    var allocations: [ScenarioAllocation]
    var totalInvested: Decimal?
    var finalValue: Decimal?
    var roiPercent: Double?
    var transactionsJson: [ScenarioTransactionRecord]?
    var sparklineData: [Double]?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case frequencyPerMonth = "frequency_per_month"
        case monthlyAmount = "monthly_amount"
        case currency
        case annualIncreasePercent = "annual_increase_percent"
        case allocations
        case totalInvested = "total_invested"
        case finalValue = "final_value"
        case roiPercent = "roi_percent"
        case transactionsJson = "transactions_json"
        case sparklineData = "sparkline_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ScenarioAllocation: Codable {
    let assetCode: String
    let percent: Double

    enum CodingKeys: String, CodingKey {
        case assetCode = "asset_code"
        case percent
    }
}

struct ScenarioTransactionRecord: Codable {
    let date: String
    let assetCode: String
    let amountUsd: Double
    let quantity: Double
    let unitPrice: Double

    enum CodingKeys: String, CodingKey {
        case date
        case assetCode = "asset_code"
        case amountUsd = "amount_usd"
        case quantity
        case unitPrice = "unit_price"
    }
}

/// Service for managing user scenarios in Supabase
final class SupabaseScenarioService: @unchecked Sendable {
    static let shared = SupabaseScenarioService()

    private let supabase: SupabaseClient

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://hplmwcjyfzjghijdqypa.supabase.co")!,
            supabaseKey:
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"
        )
    }

    /// Fetch all scenarios for the current user
    func fetchScenarios() async throws -> [UserScenario] {
        let response: [UserScenario] =
            try await supabase
            .from("user_scenarios")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    /// Create a new scenario
    func createScenario(_ scenario: UserScenario) async throws {
        try await supabase
            .from("user_scenarios")
            .insert(scenario)
            .execute()
    }

    /// Update an existing scenario
    func updateScenario(_ scenario: UserScenario) async throws {
        try await supabase
            .from("user_scenarios")
            .update(scenario)
            .eq("id", value: scenario.id.uuidString)
            .execute()
    }

    /// Delete a scenario by ID
    func deleteScenario(id: UUID) async throws {
        try await supabase
            .from("user_scenarios")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Get current user ID from Supabase Auth
    func getCurrentUserId() async -> UUID? {
        return supabase.auth.currentUser?.id
    }
}

// MARK: - Conversion helpers
extension UserScenario {
    /// Convert from ScenarioCardData (UI model) to UserScenario (Supabase model)
    static func from(
        cardData: ScenarioCardData,
        userId: UUID,
        allocations: [ScenarioAllocation],
        transactions: [ScenarioTransactionRecord]?
    ) -> UserScenario {
        return UserScenario(
            id: cardData.id,
            userId: userId,
            name: cardData.name,
            startDate: cardData.startDate,
            endDate: cardData.endDate,
            frequencyPerMonth: cardData.frequencyPerMonth,
            monthlyAmount: 0,  // Will be set from actual scenario
            currency: "USD",
            annualIncreasePercent: 0,
            allocations: allocations,
            totalInvested: cardData.totalInvestedUSD,
            finalValue: cardData.finalValueUSD,
            roiPercent: cardData.roiPercent,
            transactionsJson: transactions,
            sparklineData: cardData.sparklineData,
            createdAt: cardData.createdAt,
            updatedAt: nil
        )
    }

    /// Convert to ScenarioCardData for UI display
    func toCardData() -> ScenarioCardData {
        return ScenarioCardData(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            frequencyPerMonth: frequencyPerMonth,
            totalInvestedUSD: totalInvested ?? 0,
            finalValueUSD: finalValue ?? 0,
            roiPercent: roiPercent ?? 0,
            sparklineData: sparklineData ?? [],
            createdAt: createdAt ?? Date()
        )
    }
}
