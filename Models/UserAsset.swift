import Foundation

// MARK: - User Asset Model with Real Price Support
struct UserAsset: Identifiable, Equatable, Codable {
    var id = UUID()
    let asset: AssetCode
    var quantity: Double  // Changed to var for updates
    var unitPrice: Double  // Changed to var for average cost
    let purchaseDate: Date
    var currentPrice: Double  // Changed to var for real-time updates

    var totalCost: Double {
        quantity * unitPrice
    }

    var currentValue: Double {
        let safePrice = max(currentPrice, 0)
        return quantity * safePrice
    }

    var profitLoss: Double {
        currentValue - totalCost
    }

    var profitLossPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return (profitLoss / totalCost) * 100
    }

    // Fiyat değişimi hesaplama
    var priceChange: Double {
        currentPrice - unitPrice
    }

    var priceChangePercentage: Double {
        guard unitPrice > 0 else { return 0 }
        return (priceChange / unitPrice) * 100
    }
}
