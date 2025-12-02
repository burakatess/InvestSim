import Combine
import CoreData
import Foundation
import SwiftUI

// Models moved to separate files: Models/UserAsset.swift and Models/Trade.swift

@MainActor
final class DashboardVM: ObservableObject {
    let container: AppContainer
    let portfolioManager: PortfolioManager
    let priceManager: UnifiedPriceManager
    @Published var state: LoadableState<DashboardData> = .idle
    @Published var selectedRange: DateRange = .m3
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var lastUpdateTime: Date?
    @Published var recentTrades: [Trade] = []
    @Published var userAssets: [UserAsset] = []
    @Published var isPriceUpdating = false
    @Published var priceUpdateError: String?

    // Reentrancy guard
    private var isAddingAssetInFlight: Bool = false

    // Computed properties for UI
    var totalValue: Double {
        userAssets.reduce(0) { runningTotal, asset in
            let value = asset.quantity * max(asset.currentPrice, 0)
            return runningTotal + value
        }
    }

    var dailyChange: Double {
        // Placeholder - gerçek implementasyon gerekli
        return 0.0
    }

    var dailyChangePercentage: Double {
        // Placeholder - gerçek implementasyon gerekli
        return 0.0
    }

    var totalProfit: Double {
        userAssets.reduce(0) { $0 + $1.profitLoss }
    }

    // Price fetching
    private var cancellables = Set<AnyCancellable>()

    init(container: AppContainer, portfolioManager: PortfolioManager) {
        self.container = container
        self.portfolioManager = portfolioManager
        self.priceManager = container.priceManager

        // Portföy verilerini yükle
        if let currentPortfolioId = portfolioManager.currentPortfolioId {
            print("🚀 DashboardVM init: Portföy verileri yükleniyor \(currentPortfolioId)")
            self.currentPortfolioId = currentPortfolioId
            loadPortfolioData(for: currentPortfolioId)
        } else {
            print("⚠️ DashboardVM init: Aktif portföy bulunamadı")
        }

        loadInitialData()
        loadTradesFromCoreData()

        // Subscribe to WebSocket price updates (no more timer!)
        setupWebSocketSubscription()

        // Subscribe to portfolio changes
        setupPortfolioSubscription()
    }

    deinit {
        cancellables.removeAll()
        print("🧹 DashboardVM deinit - Subscriptions temizlendi")
    }

    // MARK: - Unified Price Observer
    private func setupUnifiedPriceObserver() {
        // Listen for price updates from UnifiedPriceManager
        priceManager.priceUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.handlePriceUpdate()
                }
            }
            .store(in: &cancellables)
    }

    private func handlePriceUpdate() async {
        // Update current prices for all assets
        var needsRecalculation = false

        for index in userAssets.indices {
            let asset = userAssets[index]
            if let definition = container.assetRepository.fetch(byCode: asset.asset.rawValue) {
                if let newPrice = try? await priceManager.price(for: definition.code) {
                    if abs(userAssets[index].currentPrice - newPrice) > 0.000001 {
                        userAssets[index].currentPrice = newPrice
                        needsRecalculation = true
                    }
                }
            }
        }

        if needsRecalculation {
            recalculateDashboard()
            lastUpdateTime = Date()
            objectWillChange.send()
        }
    }

    // MARK: - Portfolio Observer
    private var currentPortfolioId: UUID?

    private func setupPortfolioSubscription() {  // Renamed from setupPortfolioObserver
        // Listen to portfolio changes and load appropriate data
        portfolioManager.$currentPortfolioId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPortfolioId in
                if let newPortfolioId = newPortfolioId {
                    self?.switchToPortfolio(newPortfolioId)
                }
            }
            .store(in: &cancellables)
    }

    private func switchToPortfolio(_ newPortfolioId: UUID) {
        print("🔄 DashboardVM: Portföy değiştiriliyor: \(newPortfolioId)")
        print("🔄 DashboardVM: Mevcut portföy ID: \(currentPortfolioId?.uuidString ?? "nil")")

        // Eğer portföy değişmiyorsa işlem yapma
        if currentPortfolioId == newPortfolioId {
            print("⚠️ DashboardVM: Aynı portföy, işlem yapılmıyor")
            return
        }

        // Önce mevcut verileri kaydet (eğer varsa)
        if let currentId = currentPortfolioId {
            print("💾 DashboardVM: Mevcut portföy verileri kaydediliyor: \(currentId)")
            portfolioManager.savePortfolioAssets(userAssets, for: currentId)
            portfolioManager.savePortfolioTrades(recentTrades, for: currentId)
        } else {
            print("⚠️ DashboardVM: Mevcut portföy ID yok, kaydetme yapılmıyor")
        }

        // Sonra yeni portföyün verilerini yükle
        loadPortfolioData(for: newPortfolioId)

        // Yeni portföy ID'sini kaydet
        currentPortfolioId = newPortfolioId
    }

    private func loadPortfolioData(for portfolioId: UUID) {
        print("📂 Portföy verileri yükleniyor: \(portfolioId)")

        // Load assets and trades for specific portfolio
        userAssets = portfolioManager.loadPortfolioAssets(for: portfolioId)
        recentTrades = portfolioManager.loadPortfolioTrades(for: portfolioId)

        print("📊 Yüklenen varlık sayısı: \(userAssets.count)")
        print("📊 Yüklenen işlem sayısı: \(recentTrades.count)")

        // Update UI
        objectWillChange.send()
    }

    // MARK: - Initial Data Loading
    private func loadInitialData() {
        // Gerçek işlem verilerini yükle
        loadTradesFromCoreData()

        let mockSummary = AssetSummary(
            asset: .USD,
            quantity: Decimal(1000),
            averageCost: Decimal(10),
            currentPrice: Decimal(12),
            currentValue: Decimal(12000),
            profitLoss: Decimal(2000),
            profitLossPercentage: Decimal(20.0),
            allocation: Decimal(100.0),
            roi: Decimal(20.0),
            totalCost: Decimal(10000),
            totalUnits: Decimal(1000),
            avgCost: Decimal(10),
            pnl: Decimal(2000)
        )

        let mockData = DashboardData(
            summary: mockSummary,
            allocation: [],
            timeseries: PriceSeries(points: []),
            assets: [],
            recentActivity: []
        )
        self.state = .success(mockData)
    }

    // MARK: - WebSocket Price Updates
    private func setupWebSocketSubscription() {
        // Subscribe to UnifiedPriceManager's price updates
        priceManager.priceUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updatePrices()
                }
            }
            .store(in: &cancellables)

        print("📡 DashboardVM subscribed to WebSocket price updates")
    }

    // MARK: - Public Methods
    func refresh() async {
        isRefreshing = true
        await updatePrices()
        isRefreshing = false
    }

    func addAsset(asset: AssetCode, quantity: Double, unitPrice: Double, date: Date) async {
        // Debounce duplicate taps/calls
        guard !isAddingAssetInFlight else {
            print("⏹️ addAsset yoksayıldı: işleminiz zaten işleniyor")
            return
        }
        isAddingAssetInFlight = true
        defer { isAddingAssetInFlight = false }
        print("🔥🔥🔥 PORTFÖY AYRIŞTIRMALI addAsset SİSTEMİ! 🔥🔥🔥")
        print("🔥 Varlık: \(asset) - Miktar: \(quantity) adet - Fiyat: ₺\(unitPrice)")
        print("📊 Mevcut portföy: \(portfolioManager.currentPortfolio?.name ?? "Bilinmiyor")")

        guard let currentPortfolioId = portfolioManager.currentPortfolioId else {
            print("❌ Aktif portföy bulunamadı!")
            return
        }

        // 1. ÖNCE İŞLEMİ EKLE (UI hemen güncellensin)
        let newTrade = Trade(
            asset: asset,
            quantity: quantity,
            price: unitPrice,
            type: .buy,
            date: date
        )

        // Ana thread'de işlemi ekle
        DispatchQueue.main.async {
            self.recentTrades.insert(newTrade, at: 0)
            print("✅ İŞLEM EKLENDİ! recentTrades.count: \(self.recentTrades.count)")
            print(
                "✅ İşlem detayı: \(newTrade.asset.rawValue) - \(newTrade.type) - \(newTrade.quantity) adet"
            )

            // Portföy verilerini kaydet
            self.portfolioManager.savePortfolioTrades(self.recentTrades, for: currentPortfolioId)
            print("💾 İşlem portföye kaydedildi: \(currentPortfolioId)")
            print("📊 Mevcut portföydeki toplam işlem sayısı: \(self.recentTrades.count)")

            // DashboardVM'deki currentPortfolioId'yi güncelle
            self.currentPortfolioId = currentPortfolioId

            self.objectWillChange.send()
        }

        // 2. SONRA VARKLIK İŞLEMLERİNİ YAP
        do {
            guard let definition = container.assetRepository.fetch(byCode: asset.rawValue) else {
                throw UnifiedPriceError.unsupportedAsset
            }
            let currentPriceDouble = try await priceManager.price(for: definition.code)

            // Aynı varlık var mı kontrol et
            if let existingIndex = userAssets.firstIndex(where: { $0.asset == asset }) {
                // Mevcut varlığı güncelle
                let existingAsset = userAssets[existingIndex]
                let newTotalQuantity = existingAsset.quantity + quantity
                let newTotalCost = existingAsset.totalCost + (quantity * unitPrice)
                let newAveragePrice = newTotalCost / newTotalQuantity

                // Ana thread'de güncelle
                DispatchQueue.main.async {
                    self.userAssets[existingIndex].quantity = newTotalQuantity
                    self.userAssets[existingIndex].unitPrice = newAveragePrice
                    self.userAssets[existingIndex].currentPrice = currentPriceDouble
                    // Aynı kodda birden fazla satır varsa birleştir
                    _ = self.normalizeAssetsIfNeeded()
                    print(
                        "📈 Mevcut varlık güncellendi: \(asset.rawValue) - Toplam: \(newTotalQuantity) adet"
                    )

                    // Portföy verilerini kaydet
                    self.portfolioManager.savePortfolioAssets(
                        self.userAssets, for: currentPortfolioId)
                    print("💾 Varlık portföye kaydedildi: \(currentPortfolioId)")

                    // DashboardVM'deki currentPortfolioId'yi güncelle
                    self.currentPortfolioId = currentPortfolioId

                    self.objectWillChange.send()
                }

            } else {
                // Yeni varlık ekle
                let newUserAsset = UserAsset(
                    asset: asset,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    purchaseDate: date,
                    currentPrice: currentPriceDouble
                )

                // Ana thread'de ekle
                DispatchQueue.main.async {
                    self.userAssets.append(newUserAsset)
                    // Aynı kodda birden fazla satır varsa birleştir
                    _ = self.normalizeAssetsIfNeeded()
                    print(
                        "📈 Yeni varlık eklendi: \(asset.rawValue) - Toplam varlık sayısı: \(self.userAssets.count)"
                    )

                    // Portföy verilerini kaydet
                    self.portfolioManager.savePortfolioAssets(
                        self.userAssets, for: currentPortfolioId)
                    print("💾 Varlık portföye kaydedildi: \(currentPortfolioId)")

                    // DashboardVM'deki currentPortfolioId'yi güncelle
                    self.currentPortfolioId = currentPortfolioId

                    self.objectWillChange.send()
                }
            }

            // Activity oluştur
            let newActivity = ActivityItem(
                type: .buy,
                title: "\(assetName(asset)) Alımı",
                subtitle: "\(quantity) adet @ ₺\(String(format: "%.2f", unitPrice))",
                value: "₺\(String(format: "%.2f", quantity * unitPrice))",
                date: date
            )

            // Dashboard'ı güncelle
            DispatchQueue.main.async {
                self.recalculateDashboard(newActivity: newActivity)
                self.lastUpdateTime = Date()
                print("🎉 Dashboard güncellendi - Toplam varlık sayısı: \(self.userAssets.count)")
                self.objectWillChange.send()
            }

        } catch {
            print("❌ Fiyat çekme hatası: \(error.localizedDescription)")

            // Hata durumunda da varlığı ekle
            let newUserAsset = UserAsset(
                asset: asset,
                quantity: quantity,
                unitPrice: unitPrice,
                purchaseDate: date,
                currentPrice: unitPrice
            )

            DispatchQueue.main.async {
                self.userAssets.append(newUserAsset)
                print("📈 Hata durumunda varlık eklendi: \(asset.rawValue)")
                // Aynı kodda birden fazla satır varsa birleştir
                _ = self.normalizeAssetsIfNeeded()
                self.objectWillChange.send()
            }
        }

        print("🎉 addAsset işlemi tamamlandı!")
    }

    // MARK: - Asset Management
    func deleteAsset(_ asset: UserAsset) {
        withAnimation(.easeInOut(duration: 0.3)) {
            userAssets.removeAll { $0.id == asset.id }
            recalculateDashboard()
            print("🗑️ Varlık silindi: \(asset.asset.rawValue)")
        }
    }

    func sellAsset(asset assetCode: AssetCode, quantity: Double, unitPrice: Double, date: Date)
        async
    {
        guard let index = userAssets.firstIndex(where: { $0.asset == assetCode }) else {
            errorMessage("Satılacak varlık bulunamadı.")
            return
        }
        var target = userAssets[index]
        guard quantity > 0 else {
            errorMessage("Satış miktarı sıfırdan büyük olmalıdır.")
            return
        }
        guard quantity <= target.quantity + 1e-9 else {
            errorMessage("Satış miktarı mevcut bakiyeden fazla olamaz.")
            return
        }

        guard let portfolioId = currentPortfolioId ?? portfolioManager.currentPortfolioId else {
            errorMessage("Aktif portföy bulunamadı.")
            return
        }

        let remainingQuantity = max(target.quantity - quantity, 0)
        let currentPriceDouble: Double
        do {
            if let definition = container.assetRepository.fetch(byCode: assetCode.rawValue) {
                currentPriceDouble = try await priceManager.price(for: definition.code)
            } else {
                currentPriceDouble = unitPrice
            }
        } catch {
            currentPriceDouble = unitPrice
        }

        // Ana thread'de varlığı güncelle
        DispatchQueue.main.async {
            if remainingQuantity > 0 {
                // Mevcut varlığı güncelle
                self.userAssets[index].quantity = remainingQuantity
                self.userAssets[index].currentPrice = currentPriceDouble
                print(
                    "📉 Varlık güncellendi: \(assetCode.rawValue) - Kalan: \(remainingQuantity) adet"
                )
            } else {
                // Varlığı tamamen kaldır
                self.userAssets.remove(at: index)
                print("🗑️ Varlık kaldırıldı: \(assetCode.rawValue)")
            }
            _ = self.normalizeAssetsIfNeeded()
            self.portfolioManager.savePortfolioAssets(self.userAssets, for: portfolioId)
            self.currentPortfolioId = portfolioId
            self.objectWillChange.send()
        }

        let activity = ActivityItem(
            type: .sell,
            title: "\(assetName(assetCode)) Satışı",
            subtitle:
                "\(String(format: "%.4f", quantity)) adet @ ₺\(String(format: "%.2f", unitPrice))",
            value: "₺\(String(format: "%.2f", quantity * unitPrice))",
            date: date
        )

        // Trade oluştur ve ekle
        let newTrade = Trade(
            asset: assetCode,
            quantity: quantity,
            price: unitPrice,
            type: .sell,
            date: date
        )

        // Ana thread'de işlemi ekle ve dashboard'ı güncelle
        DispatchQueue.main.async {
            self.recentTrades.insert(newTrade, at: 0)
            print("✅ Satış işlemi eklendi - recentTrades.count: \(self.recentTrades.count)")
            print(
                "✅ İşlem detayı: \(newTrade.asset.rawValue) - \(newTrade.type) - \(newTrade.quantity) adet"
            )

            self.portfolioManager.savePortfolioTrades(self.recentTrades, for: portfolioId)
            self.lastUpdateTime = Date()
            self.recalculateDashboard(newActivity: activity)
            print("🎉 Satış işlemi tamamlandı - Toplam varlık sayısı: \(self.userAssets.count)")
            self.objectWillChange.send()
        }
    }

    // MARK: - Dashboard Calculations
    func recalculateDashboard() {
        print("🔄 Dashboard yeniden hesaplanıyor...")

        let assetsForCalculation = normalizeAssetsIfNeeded()

        if assetsForCalculation.isEmpty {
            loadInitialData()
            return
        }

        // Mevcut activity'leri koru
        var currentActivities: [ActivityItem] = []
        if case .success(let data) = state {
            currentActivities = data.recentActivity
        }

        // Yeni hesaplamalar
        let totalCost = assetsForCalculation.reduce(0) { $0 + $1.totalCost }
        let totalCurrentValue = assetsForCalculation.reduce(0) { $0 + $1.currentValue }
        let totalProfitLoss = totalCurrentValue - totalCost
        let totalProfitLossPercentage = totalCost > 0 ? (totalProfitLoss / totalCost) * 100 : 0

        let totalQuantity = assetsForCalculation.reduce(0) { $0 + $1.quantity }
        let avgCost = totalQuantity > 0 ? totalCost / totalQuantity : 0
        let avgPrice = totalQuantity > 0 ? totalCurrentValue / totalQuantity : 0

        let mainAsset =
            assetsForCalculation.max(by: { $0.currentValue < $1.currentValue })?.asset ?? .USD

        let updatedSummary = AssetSummary(
            asset: mainAsset,
            quantity: Decimal(totalQuantity),
            averageCost: Decimal(avgCost),
            currentPrice: Decimal(avgPrice),
            currentValue: Decimal(totalCurrentValue),
            profitLoss: Decimal(totalProfitLoss),
            profitLossPercentage: Decimal(totalProfitLossPercentage),
            allocation: Decimal(100.0),
            roi: Decimal(totalProfitLossPercentage),
            totalCost: Decimal(totalCost),
            totalUnits: Decimal(totalQuantity),
            avgCost: Decimal(avgCost),
            pnl: Decimal(totalProfitLoss)
        )

        let updatedData = DashboardData(
            summary: updatedSummary,
            allocation: [],
            timeseries: PriceSeries(points: []),
            assets: [],
            recentActivity: currentActivities
        )

        state = .success(updatedData)
        print("✅ Dashboard yeniden hesaplandı!")
    }

    private func recalculateDashboard(newActivity: ActivityItem) {
        // Activity listesini güncelle
        var updatedActivities: [ActivityItem] = []
        if case .success(let currentData) = state {
            updatedActivities = currentData.recentActivity
        }
        updatedActivities.insert(newActivity, at: 0)
        if updatedActivities.count > 10 {
            updatedActivities = Array(updatedActivities.prefix(10))
        }

        // Dashboard'ı yeniden hesapla
        recalculateDashboard()

        // Activity'yi güncelle
        if case .success(var data) = state {
            data.recentActivity = updatedActivities
            state = .success(data)
        }
    }

    // MARK: - Core Data Trade Management
    private func loadTradesFromCoreData() {
        print("📊 İşlem geçmişi sistemi başlatılıyor...")
        recentTrades.removeAll()
        print("🧹 Mevcut işlemler temizlendi - recentTrades.count: \(recentTrades.count)")
    }

    private func saveTradeToCoreData(_ trade: Trade) {
        // İşlemi recentTrades listesine ekle (zaten eklenmiş olmalı)
        // Bu fonksiyon sadece log için kullanılıyor
        print(
            "💾 İşlem kaydedildi: \(trade.type == .buy ? "Alış" : "Satış") - \(trade.asset.rawValue) - \(trade.quantity) adet @ ₺\(trade.price)"
        )
    }

    // MARK: - Helper Methods
    private func assetName(_ asset: AssetCode) -> String {
        return asset.displayName
    }

    // MARK: - Computed Properties for UI
    var recentActivity: [ActivityItem] {
        if case .success(let data) = state {
            return data.recentActivity
        }
        return []
    }

    var totalInvestment: String {
        if case .success(let data) = state {
            return
                "₺\(String(format: "%.2f", NSDecimalNumber(decimal: data.summary.totalCost).doubleValue))"
        }
        return "₺0,00"
    }

    var assetCount: String {
        return "\(userAssets.count)"
    }

    var profitColor: Color {
        if case .success(let data) = state {
            return NSDecimalNumber(decimal: data.summary.profitLoss).doubleValue >= 0
                ? .green : .red
        }
        return .green
    }

    var lastUpdateText: String {
        guard let lastUpdate = lastUpdateTime else { return "Henüz güncellenmedi" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Son güncelleme: \(formatter.string(from: lastUpdate))"
    }
}

// MARK: - Normalization
extension DashboardVM {
    private func normalizeAssetsIfNeeded() -> [UserAsset] {
        guard !userAssets.isEmpty else { return [] }
        let grouped = Dictionary(grouping: userAssets, by: { $0.asset })
        guard grouped.count != userAssets.count else {
            return userAssets
        }

        var merged: [UserAsset] = []
        for (assetCode, assets) in grouped {
            let totalQuantity = assets.reduce(0) { $0 + $1.quantity }
            let totalCost = assets.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
            let averageCost = totalQuantity == 0 ? 0 : totalCost / totalQuantity
            let latestPrice = assets.last?.currentPrice ?? assets.first?.currentPrice ?? 0
            let earliestDate =
                assets.min(by: { $0.purchaseDate < $1.purchaseDate })?.purchaseDate ?? Date()

            let mergedAsset = UserAsset(
                asset: assetCode,
                quantity: totalQuantity,
                unitPrice: averageCost,
                purchaseDate: earliestDate,
                currentPrice: latestPrice
            )
            merged.append(mergedAsset)
        }

        merged.sort { $0.asset.rawValue < $1.asset.rawValue }
        userAssets = merged
        return merged
    }

    private func errorMessage(_ message: String) {
        print("⚠️ \(message)")
        // TODO: route to UI if needed
    }

    // MARK: - Real-time Price Updates
    // setupPriceUpdates() metodu kaldırıldı - startPriceUpdates() kullanılıyor

    private func updatePrices() async {
        guard !userAssets.isEmpty else { return }

        isPriceUpdating = true
        priceUpdateError = nil

        var updatedPrices: [AssetCode: Double] = [:]
        do {
            for asset in userAssets {
                guard let definition = container.assetRepository.fetch(byCode: asset.asset.rawValue)
                else {
                    continue
                }
                let price = try await priceManager.price(for: definition.code)
                updatedPrices[asset.asset] = price
            }

            for index in userAssets.indices {
                let assetCode = userAssets[index].asset
                if let price = updatedPrices[assetCode] {
                    userAssets[index].currentPrice = price
                }
            }

            lastUpdateTime = Date()
            print("✅ Fiyatlar güncellendi: \(updatedPrices.count) varlık")

            // Dashboard'ı yeniden hesapla
            recalculateDashboard()
            objectWillChange.send()

        } catch {
            priceUpdateError = "Fiyat güncelleme hatası: \(error.localizedDescription)"
            print("❌ Fiyat güncelleme hatası: \(error)")
        }

        isPriceUpdating = false
    }

    func cleanup() {
        cancellables.removeAll()
        print("🧹 DashboardVM cleanup çağrıldı")
    }
}
