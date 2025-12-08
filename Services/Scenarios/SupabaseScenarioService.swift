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

    // Custom decoder to handle Supabase date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        frequencyPerMonth = try container.decode(Int.self, forKey: .frequencyPerMonth)
        currency = try container.decode(String.self, forKey: .currency)
        allocations = try container.decode([ScenarioAllocation].self, forKey: .allocations)
        transactionsJson = try container.decodeIfPresent(
            [ScenarioTransactionRecord].self, forKey: .transactionsJson)
        sparklineData = try container.decodeIfPresent([Double].self, forKey: .sparklineData)

        // Handle Decimal - Supabase returns as String or Number
        if let decimalString = try? container.decode(String.self, forKey: .monthlyAmount) {
            monthlyAmount = Decimal(string: decimalString) ?? 0
        } else if let doubleValue = try? container.decode(Double.self, forKey: .monthlyAmount) {
            monthlyAmount = Decimal(doubleValue)
        } else {
            monthlyAmount = 0
        }

        if let decimalString = try? container.decode(String.self, forKey: .annualIncreasePercent) {
            annualIncreasePercent = Decimal(string: decimalString) ?? 0
        } else if let doubleValue = try? container.decode(
            Double.self, forKey: .annualIncreasePercent)
        {
            annualIncreasePercent = Decimal(doubleValue)
        } else {
            annualIncreasePercent = 0
        }

        if let decimalString = try? container.decode(String.self, forKey: .totalInvested) {
            totalInvested = Decimal(string: decimalString)
        } else if let doubleValue = try? container.decode(Double.self, forKey: .totalInvested) {
            totalInvested = Decimal(doubleValue)
        } else {
            totalInvested = nil
        }

        if let decimalString = try? container.decode(String.self, forKey: .finalValue) {
            finalValue = Decimal(string: decimalString)
        } else if let doubleValue = try? container.decode(Double.self, forKey: .finalValue) {
            finalValue = Decimal(doubleValue)
        } else {
            finalValue = nil
        }

        // ROI percent - can be String or Double
        if let doubleValue = try? container.decode(Double.self, forKey: .roiPercent) {
            roiPercent = doubleValue
        } else if let decimalString = try? container.decode(String.self, forKey: .roiPercent) {
            roiPercent = Double(decimalString)
        } else {
            roiPercent = nil
        }

        // Date parsing - Supabase DATE format is "YYYY-MM-DD"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let startDateString = try container.decode(String.self, forKey: .startDate)
        if let date = dateFormatter.date(from: startDateString) {
            startDate = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .startDate, in: container,
                debugDescription: "Invalid date format: \(startDateString)")
        }

        let endDateString = try container.decode(String.self, forKey: .endDate)
        if let date = dateFormatter.date(from: endDateString) {
            endDate = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .endDate, in: container,
                debugDescription: "Invalid date format: \(endDateString)")
        }

        // Timestamp parsing - Supabase TIMESTAMPTZ format
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoFormatterWithoutFraction = ISO8601DateFormatter()
        isoFormatterWithoutFraction.formatOptions = [.withInternetDateTime]

        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt =
                isoFormatter.date(from: createdAtString)
                ?? isoFormatterWithoutFraction.date(from: createdAtString)
        } else {
            createdAt = nil
        }

        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt =
                isoFormatter.date(from: updatedAtString)
                ?? isoFormatterWithoutFraction.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }

    // Standard memberwise init for creating new scenarios
    init(
        id: UUID,
        userId: UUID,
        name: String,
        startDate: Date,
        endDate: Date,
        frequencyPerMonth: Int,
        monthlyAmount: Decimal,
        currency: String,
        annualIncreasePercent: Decimal,
        allocations: [ScenarioAllocation],
        totalInvested: Decimal?,
        finalValue: Decimal?,
        roiPercent: Double?,
        transactionsJson: [ScenarioTransactionRecord]?,
        sparklineData: [Double]?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.frequencyPerMonth = frequencyPerMonth
        self.monthlyAmount = monthlyAmount
        self.currency = currency
        self.annualIncreasePercent = annualIncreasePercent
        self.allocations = allocations
        self.totalInvested = totalInvested
        self.finalValue = finalValue
        self.roiPercent = roiPercent
        self.transactionsJson = transactionsJson
        self.sparklineData = sparklineData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
