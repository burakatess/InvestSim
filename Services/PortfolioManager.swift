import Foundation
import SwiftUI
import Combine

class PortfolioManager: ObservableObject {
    @Published var portfolios: [Portfolio] = []
    @Published var currentPortfolioId: UUID?
    private let maxPortfolios = 5
    
    // Her portföy için ayrı veri anahtarları
    private let userDefaults = UserDefaults.standard
    private let portfoliosKey = "saved_portfolios"
    private let currentPortfolioKey = "current_portfolio_id"
    
    // Portföy verileri için anahtarlar
    private func portfolioAssetsKey(for portfolioId: UUID) -> String {
        return "portfolio_\(portfolioId.uuidString)_assets"
    }
    
    private func portfolioTradesKey(for portfolioId: UUID) -> String {
        return "portfolio_\(portfolioId.uuidString)_trades"
    }
    
    init() {
        loadPortfolios()
        loadCurrentPortfolioId()
        
        // Eğer hiç portföy yoksa varsayılan oluştur
        if portfolios.isEmpty {
            createDefaultPortfolio()
        }
        
        // Eğer currentPortfolioId yoksa veya geçersizse ilk portföyü seç
        if currentPortfolioId == nil || currentPortfolio == nil {
            currentPortfolioId = portfolios.first?.id
            saveCurrentPortfolioId()
        }
    }
    
    var currentPortfolio: Portfolio? {
        portfolios.first { $0.id == currentPortfolioId }
    }
    
    func loadPortfolios() {
        if let data = userDefaults.data(forKey: portfoliosKey),
           let decoded = try? JSONDecoder().decode([Portfolio].self, from: data) {
            portfolios = decoded
        }
    }
    
    private func loadCurrentPortfolioId() {
        if let currentIdData = userDefaults.data(forKey: currentPortfolioKey),
           let currentId = try? JSONDecoder().decode(UUID.self, from: currentIdData) {
            currentPortfolioId = currentId
        }
    }
    
    private func saveCurrentPortfolioId() {
        if let currentId = currentPortfolioId {
            if let data = try? JSONEncoder().encode(currentId) {
                userDefaults.set(data, forKey: currentPortfolioKey)
            }
        }
    }
    
    func savePortfolios() {
        if let encoded = try? JSONEncoder().encode(portfolios) {
            userDefaults.set(encoded, forKey: portfoliosKey)
        }
        
        if let currentId = currentPortfolioId,
           let encoded = try? JSONEncoder().encode(currentId) {
            userDefaults.set(encoded, forKey: currentPortfolioKey)
        }
    }
    
    func createDefaultPortfolio() {
        let defaultPortfolio = Portfolio(name: "Ana Portföy", isDefault: true, color: .blue)
        portfolios = [defaultPortfolio]
        currentPortfolioId = defaultPortfolio.id
        savePortfolios()
    }
    
    enum PortfolioError: Error, LocalizedError {
        case maxLimitReached
        case minLimitReached
        case invalidName
        
        var errorDescription: String? {
            switch self {
            case .maxLimitReached: return "Maksimum 5 portföy oluşturabilirsiniz."
            case .minLimitReached: return "En az bir portföy bulunmalıdır."
            case .invalidName: return "Lütfen geçerli bir portföy adı girin."
            }
        }
    }
    
    var canAddPortfolio: Bool { portfolios.count < maxPortfolios }
    
    @discardableResult
    func addPortfolio(name: String, color: PortfolioColor) throws -> Portfolio {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PortfolioError.invalidName }
        guard canAddPortfolio else { throw PortfolioError.maxLimitReached }
        let newPortfolio = Portfolio(name: name, color: color)
        portfolios.append(newPortfolio)
        savePortfolios()
        return newPortfolio
    }
    
    func updatePortfolio(_ portfolio: Portfolio) {
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
            savePortfolios()
        }
    }
    
    func deletePortfolio(_ portfolio: Portfolio) throws {
        // En az bir portföy kalmalı
        guard portfolios.count > 1 else { throw PortfolioError.minLimitReached }

        // Portföye ait kayıtlı verileri temizle
        clearPortfolioData(for: portfolio.id)

        portfolios.removeAll { $0.id == portfolio.id }

        // Eğer silinen portföy aktif portföyse, ilk portföye geç
        if currentPortfolioId == portfolio.id {
            currentPortfolioId = portfolios.first?.id
        }
        
        savePortfolios()
    }
    
    func switchToPortfolio(_ portfolio: Portfolio) {
        print("🔄 PortfolioManager: Portföy değiştiriliyor \(portfolio.name) (ID: \(portfolio.id))")
        print("🔄 Eski portföy ID: \(currentPortfolioId?.uuidString ?? "nil")")
        print("🔄 Yeni portföy ID: \(portfolio.id)")
        
        // Eğer aynı portföy seçiliyorsa işlem yapma
        if currentPortfolioId == portfolio.id {
            print("⚠️ PortfolioManager: Aynı portföy seçili, işlem yapılmıyor")
            return
        }
        
        // Yeni portföy ID'sini ayarla
        currentPortfolioId = portfolio.id
        saveCurrentPortfolioId()
        
        print("✅ PortfolioManager: Portföy değiştirildi")
    }
    
    func canDeletePortfolio(_ portfolio: Portfolio) -> Bool { portfolios.count > 1 && !portfolio.isDefault }
    
    // MARK: - Portfolio Data Management
    
    func savePortfolioAssets(_ assets: [UserAsset], for portfolioId: UUID) {
        print("💾 PortfolioManager: Varlıklar kaydediliyor - Portföy: \(portfolioId), Varlık sayısı: \(assets.count)")
        if let encoded = try? JSONEncoder().encode(assets) {
            userDefaults.set(encoded, forKey: portfolioAssetsKey(for: portfolioId))
            print("✅ PortfolioManager: Varlıklar başarıyla kaydedildi")
        } else {
            print("❌ PortfolioManager: Varlık kaydetme hatası")
        }
    }
    
    func loadPortfolioAssets(for portfolioId: UUID) -> [UserAsset] {
        print("📂 PortfolioManager: Varlıklar yükleniyor - Portföy: \(portfolioId)")
        if let data = userDefaults.data(forKey: portfolioAssetsKey(for: portfolioId)),
           let decoded = try? JSONDecoder().decode([UserAsset].self, from: data) {
            print("✅ PortfolioManager: \(decoded.count) varlık yüklendi")
            return decoded
        }
        print("⚠️ PortfolioManager: Varlık bulunamadı veya boş")
        return []
    }
    
    func savePortfolioTrades(_ trades: [Trade], for portfolioId: UUID) {
        print("💾 PortfolioManager: İşlemler kaydediliyor - Portföy: \(portfolioId), İşlem sayısı: \(trades.count)")
        if let encoded = try? JSONEncoder().encode(trades) {
            userDefaults.set(encoded, forKey: portfolioTradesKey(for: portfolioId))
            print("✅ PortfolioManager: İşlemler başarıyla kaydedildi")
        } else {
            print("❌ PortfolioManager: İşlem kaydetme hatası")
        }
    }
    
    func loadPortfolioTrades(for portfolioId: UUID) -> [Trade] {
        print("📂 PortfolioManager: İşlemler yükleniyor - Portföy: \(portfolioId)")
        if let data = userDefaults.data(forKey: portfolioTradesKey(for: portfolioId)),
           let decoded = try? JSONDecoder().decode([Trade].self, from: data) {
            print("✅ PortfolioManager: \(decoded.count) işlem yüklendi")
            return decoded
        }
        print("⚠️ PortfolioManager: İşlem bulunamadı veya boş")
        return []
    }
    
    func clearPortfolioData(for portfolioId: UUID) {
        userDefaults.removeObject(forKey: portfolioAssetsKey(for: portfolioId))
        userDefaults.removeObject(forKey: portfolioTradesKey(for: portfolioId))
    }
    
    func migrateDataToCurrentPortfolio(assets: [UserAsset], trades: [Trade]) {
        guard let currentId = currentPortfolioId else { return }
        
        // Mevcut verileri yükle
        var currentAssets = loadPortfolioAssets(for: currentId)
        var currentTrades = loadPortfolioTrades(for: currentId)
        
        // Yeni verileri ekle
        currentAssets.append(contentsOf: assets)
        currentTrades.append(contentsOf: trades)
        
        // Kaydet
        savePortfolioAssets(currentAssets, for: currentId)
        savePortfolioTrades(currentTrades, for: currentId)
    }
}
