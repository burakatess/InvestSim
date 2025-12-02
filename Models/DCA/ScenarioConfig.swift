import Foundation

struct ScenarioConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var initialInvestment: Decimal
    var monthlyInvestment: Decimal
    var investmentCurrency: AssetCode
    var startDate: Date
    var endDate: Date
    var intervalRawValue: Int // Calendar.Component için raw value
    var frequency: Int // Her X günde/haftada/ayda bir
    var slippage: Decimal // % olarak (örn: 0.001 = %0.1)
    var transactionFee: Decimal // % olarak (örn: 0.0005 = %0.05)
    var assetAllocations: [AssetAllocation] // Varlık dağılımları
    // Ay bazında çoklu gün seçimi için opsiyonel alan (ör. [5, 8])
    var customDaysOfMonth: [Int]? = nil
    
    var interval: Calendar.Component {
        get {
            switch intervalRawValue {
            case 0: return .day
            case 1: return .weekOfMonth
            case 2: return .month
            default: return .month
            }
        }
        set {
            switch newValue {
            case .day: intervalRawValue = 0
            case .weekOfMonth: intervalRawValue = 1
            case .month: intervalRawValue = 2
            default: intervalRawValue = 2
            }
        }
    }

    init(id: UUID = UUID(), name: String, initialInvestment: Decimal, monthlyInvestment: Decimal, investmentCurrency: AssetCode, startDate: Date, endDate: Date, interval: Calendar.Component, frequency: Int, slippage: Decimal, transactionFee: Decimal, assetAllocations: [AssetAllocation] = [], customDaysOfMonth: [Int]? = nil) {
        self.id = id
        self.name = name
        self.initialInvestment = initialInvestment
        self.monthlyInvestment = monthlyInvestment
        self.investmentCurrency = investmentCurrency
        self.startDate = startDate
        self.endDate = endDate
        self.frequency = frequency
        self.slippage = slippage
        self.transactionFee = transactionFee
        self.assetAllocations = assetAllocations
        self.customDaysOfMonth = customDaysOfMonth
        
        // intervalRawValue'yu manuel olarak set et
        switch interval {
        case .day: self.intervalRawValue = 0
        case .weekOfMonth: self.intervalRawValue = 1
        case .month: self.intervalRawValue = 2
        default: self.intervalRawValue = 2
        }
    }
    
    // MARK: - Asset Allocation Helpers
    
    /// Toplam ağırlık yüzdesini döndürür
    var totalWeightPercentage: Decimal {
        return assetAllocations.reduce(0) { $0 + $1.weightPercentage }
    }
    
    /// Ağırlık dağılımı geçerli mi? (tam %100 olmalı)
    var isValidWeightDistribution: Bool {
        let tolerance: Decimal = 0.05
        let difference = (totalWeightPercentage - 100).magnitude
        return difference <= tolerance
    }
    
    /// Varlık ekler
    mutating func addAsset(_ assetCode: AssetCode, weight: Decimal) {
        // Eğer varlık zaten varsa güncelle
        if let index = assetAllocations.firstIndex(where: { $0.assetCode == assetCode }) {
            assetAllocations[index].weight = weight
        } else {
            // Yeni varlık ekle
            let allocation = AssetAllocation(assetCode: assetCode, weight: weight)
            assetAllocations.append(allocation)
        }
    }
    
    /// Varlık kaldırır
    mutating func removeAsset(_ assetCode: AssetCode) {
        assetAllocations.removeAll { $0.assetCode == assetCode }
    }
    
    /// Varlık ağırlığını günceller
    mutating func updateAssetWeight(_ assetCode: AssetCode, weight: Decimal) {
        if let index = assetAllocations.firstIndex(where: { $0.assetCode == assetCode }) {
            assetAllocations[index].weight = weight
        }
    }
    
    /// Tüm ağırlıkları sıfırlar
    mutating func resetAllWeights() {
        for index in assetAllocations.indices {
            assetAllocations[index].weight = 0
        }
    }
    
    /// Ağırlıkları otomatik olarak eşit dağıtır
    mutating func distributeWeightsEqually() {
        guard !assetAllocations.isEmpty else { return }
        let count = Decimal(assetAllocations.count)
        let baseWeight = (Decimal(1) / count).rounded(scale: 4)

        for index in assetAllocations.indices {
            assetAllocations[index].weight = baseWeight
        }

        normalizeWeights()
    }

    /// Eksik yüzdeleri eşit olarak dağıtır
    mutating func fillRemainingEvenly() {
        guard !assetAllocations.isEmpty else { return }

        let currentTotal = assetAllocations.reduce(Decimal(0)) { $0 + max(0, $1.weight) }
        guard currentTotal < 1 else {
            normalizeWeights()
            return
        }

        let remaining = (Decimal(1) - currentTotal).rounded(scale: 4)
        guard remaining > 0 else {
            normalizeWeights()
            return
        }

        let targetIndices = Array(assetAllocations.indices)
        guard !targetIndices.isEmpty else { return }

        let count = Decimal(targetIndices.count)
        let perAsset = (remaining / count).rounded(scale: 4)

        for index in targetIndices {
            assetAllocations[index].weight = (max(0, assetAllocations[index].weight) + perAsset).rounded(scale: 4)
        }

        normalizeWeights()
    }

    /// Ağırlıkları %100 olacak şekilde normalleştirir
    private mutating func normalizeWeights() {
        guard !assetAllocations.isEmpty else { return }
        if assetAllocations.count == 1 {
            assetAllocations[0].weight = 1
            return
        }

        let total = assetAllocations.reduce(Decimal(0)) { $0 + max(0, $1.weight) }
        guard total > 0 else {
            assetAllocations[0].weight = 1
            for index in assetAllocations.indices.dropFirst() {
                assetAllocations[index].weight = 0
            }
            return
        }

        var normalizedValues: [Decimal] = Array(repeating: 0, count: assetAllocations.count)
        var cumulative: Decimal = 0

        for index in assetAllocations.indices {
            if index == assetAllocations.index(before: assetAllocations.endIndex) {
                let remaining = (Decimal(1) - cumulative).rounded(scale: 4)
                normalizedValues[index] = max(0, remaining)
            } else {
                let normalized = (max(0, assetAllocations[index].weight) / total).rounded(scale: 4)
                normalizedValues[index] = normalized
                cumulative += normalized
            }
        }

        let sum = normalizedValues.reduce(Decimal(0), +)
        if sum != 1, let adjustIndex = normalizedValues.indices.max(by: { normalizedValues[$0] < normalizedValues[$1] }) {
            normalizedValues[adjustIndex] = (normalizedValues[adjustIndex] + (Decimal(1) - sum)).rounded(scale: 4)
        }

        for index in assetAllocations.indices {
            normalizedValues[index] = max(0, normalizedValues[index])
            assetAllocations[index].weight = normalizedValues[index]
        }
    }
}
