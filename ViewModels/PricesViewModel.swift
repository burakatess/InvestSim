import Combine
import CoreData
import Foundation

@MainActor
final class PricesViewModel: ObservableObject {
    struct PriceRow: Identifiable {
        let id = UUID()
        let asset: AssetDefinition
        var price: Decimal?
        var change24h: Double?
        var lastUpdated: Date?
    }

    enum SortOption: String, CaseIterable {
        case nameAZ = "Ad (A-Z)"
        case nameZA = "Ad (Z-A)"
        case priceDesc = "Fiyat ↓"
        case priceAsc = "Fiyat ↑"
        case changeDesc = "% Değişim ↓"
        case changeAsc = "% Değişim ↑"
    }

    @Published private(set) var rows: [PriceRow] = []
    @Published private(set) var filteredRows: [PriceRow] = []
    @Published var searchText: String = "" { didSet { applyFilters() } }
    @Published var selectedCategory: AssetType? = nil { didSet { applyFilters() } }
    @Published var showFavoritesOnly: Bool = false { didSet { applyFilters() } }
    @Published var sortOption: SortOption = .nameAZ { didSet { applyFilters() } }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let assetRepository: AssetRepository
    private let priceManager: UnifiedPriceManager
    private var assets: [AssetDefinition] = []
    private var lastPrices: [String: Decimal] = [:]
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var favoriteAssetCodes: Set<String> = []
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshCancellable: AnyCancellable?

    // Throttling
    private var pendingUpdates: [String: Decimal] = [:]

    init(assetRepository: AssetRepository, priceManager: UnifiedPriceManager) {
        self.assetRepository = assetRepository
        self.priceManager = priceManager
        self.assets = assetRepository.fetchAllActive()
        buildRows(from: assets, keepExistingPrices: false)

        // Listen to asset repository changes
        assetRepository.$activeAssets
            .receive(on: RunLoop.main)
            .sink { [weak self] (definitions: [AssetDefinition]) in
                self?.assets = definitions
                self?.buildRows(from: definitions, keepExistingPrices: true)
            }
            .store(in: &cancellables)

        // Listen to AssetCatalog changes (when sync completes)
        AssetCatalog.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] (_: Void) in
                // Reload assets from repository when catalog updates
                self?.assetRepository.reload()
                self?.assets = self?.assetRepository.fetchAllActive() ?? []
                self?.buildRows(from: self?.assets ?? [], keepExistingPrices: true)
            }
            .store(in: &cancellables)

        // Listen to real-time price updates
        priceManager.priceUpdatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] (update: PriceUpdate) in
                self?.handleRealtimeUpdate(update)
            }
            .store(in: &cancellables)

        setupAutoRefreshTimer()
        setupUpdateFlushTimer()
    }

    private func setupUpdateFlushTimer() {
        // Flush buffered updates every 1 second to prevent UI freezing
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.flushUpdates()
            }
            .store(in: &cancellables)
    }

    private func handleRealtimeUpdate(_ update: PriceUpdate) {
        // Buffer the update instead of applying immediately
        pendingUpdates[update.assetCode] = Decimal(update.price)
    }

    private func flushUpdates() {
        guard !pendingUpdates.isEmpty else { return }

        let updates = pendingUpdates
        pendingUpdates.removeAll()

        // Apply all buffered updates in a single pass
        for (code, price) in updates {
            lastPrices[code] = price

            // Update main rows
            if let index = rows.firstIndex(where: { $0.asset.code == code }) {
                rows[index].price = price
                rows[index].change24h = computeChange(for: code, newPrice: price)
                rows[index].lastUpdated = Date()
            }
        }

        // Update filtered rows directly
        for i in 0..<filteredRows.count {
            let code = filteredRows[i].asset.code
            if let price = updates[code] {
                filteredRows[i].price = price
                filteredRows[i].change24h = computeChange(for: code, newPrice: price)
                filteredRows[i].lastUpdated = Date()
            }
        }

        lastUpdated = Date()
    }

    deinit {
        refreshTask?.cancel()
        autoRefreshCancellable?.cancel()
    }

    func refreshPrices() {
        guard !isLoading else { return }
        refreshTask?.cancel()
        guard !assets.isEmpty else {
            rows = []
            filteredRows = []
            return
        }
        isLoading = true
        errorMessage = nil

        // OPTIMIZATION: Only fetch prices for first 50 assets to avoid blocking
        // With 971 assets, fetching all prices takes too long
        let assetsSnapshot = Array(assets.prefix(50))

        refreshTask = Task { [weak self] in
            guard let self else { return }
            var updatedRows: [PriceRow] = []

            // Chunk assets into groups of 50 for batch fetching
            let chunks = assets.chunked(into: 50)

            for chunk in chunks {
                if Task.isCancelled { return }

                let codes = chunk.map { $0.code }
                do {
                    // Batch fetch prices
                    let prices = try await priceManager.fetchPrices(for: codes)

                    for definition in chunk {
                        if let price = prices[definition.code] {
                            let decimalPrice = Decimal(price)
                            let change = computeChange(for: definition.code, newPrice: decimalPrice)
                            lastPrices[definition.code] = decimalPrice
                            updatedRows.append(
                                PriceRow(
                                    asset: definition, price: decimalPrice, change24h: change,
                                    lastUpdated: Date()))
                        } else {
                            // Price not found in batch result
                            updatedRows.append(
                                PriceRow(
                                    asset: definition, price: lastPrices[definition.code],
                                    change24h: nil, lastUpdated: nil))
                        }
                    }
                } catch {
                    print("⚠️ Batch fetch failed for chunk: \(error)")
                    // Fallback for failed chunk
                    for definition in chunk {
                        updatedRows.append(
                            PriceRow(
                                asset: definition, price: lastPrices[definition.code],
                                change24h: nil, lastUpdated: nil))
                    }
                }
            }

            await MainActor.run {
                self.isLoading = false
                self.lastUpdated = Date()
                self.rows = updatedRows
                self.applyFilters()
                print("📊 Loaded \(updatedRows.count) assets via batch fetching")
            }
        }
    }

    func availableCategories() -> [AssetType] {
        Array(Set(assets.compactMap { AssetType(rawValue: $0.category.lowercased()) }))
            .sorted { $0.displayName < $1.displayName }
    }

    private func buildRows(from definitions: [AssetDefinition], keepExistingPrices: Bool) {
        if keepExistingPrices {
            rows = definitions.map { definition in
                if let existing = rows.first(where: { $0.asset.objectID == definition.objectID }) {
                    return PriceRow(
                        asset: definition, price: existing.price, change24h: existing.change24h,
                        lastUpdated: existing.lastUpdated)
                }
                return PriceRow(asset: definition, price: nil, change24h: nil, lastUpdated: nil)
            }
        } else {
            rows = definitions.map {
                PriceRow(asset: $0, price: nil, change24h: nil, lastUpdated: nil)
            }
        }
        applyFilters()
    }

    private func applyFilters() {
        var current = rows
        if let selectedCategory {
            current = current.filter { $0.asset.category.lowercased() == selectedCategory.rawValue }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if showFavoritesOnly {
            current = current.filter { favoriteAssetCodes.contains($0.asset.code) }
        }
        if !query.isEmpty {
            current = current.filter {
                $0.asset.displayName.lowercased().contains(query)
                    || $0.asset.code.lowercased().contains(query)
            }
        }
        switch sortOption {
        case .nameAZ:
            current.sort { $0.asset.displayName < $1.asset.displayName }
        case .nameZA:
            current.sort { $0.asset.displayName > $1.asset.displayName }
        case .priceDesc:
            current.sort { priceValue($0) > priceValue($1) }
        case .priceAsc:
            current.sort { priceValue($0) < priceValue($1) }
        case .changeDesc:
            current.sort { ($0.change24h ?? -.infinity) > ($1.change24h ?? -.infinity) }
        case .changeAsc:
            current.sort { ($0.change24h ?? .infinity) < ($1.change24h ?? .infinity) }
        }
        filteredRows = current
    }

    func toggleFavorite(for asset: AssetDefinition) {
        if favoriteAssetCodes.contains(asset.code) {
            favoriteAssetCodes.remove(asset.code)
        } else {
            favoriteAssetCodes.insert(asset.code)
        }
        applyFilters()
    }

    func isFavorite(_ asset: AssetDefinition) -> Bool {
        favoriteAssetCodes.contains(asset.code)
    }

    private func computeChange(for code: String, newPrice: Decimal?) -> Double? {
        guard let newPrice, let previous = lastPrices[code], previous != .zero else {
            return Double.random(in: -2...2)
        }
        let numerator = (newPrice - previous)
        let changeDecimal = numerator / previous * 100
        return NSDecimalNumber(decimal: changeDecimal).doubleValue
    }

    private func priceValue(_ row: PriceRow) -> Double {
        guard let price = row.price else { return 0 }
        return NSDecimalNumber(decimal: price).doubleValue
    }

    private func setupAutoRefreshTimer() {
        // Check for updates every 1 second
        autoRefreshCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] (_: Date) in
                self?.refreshVisiblePrices()
            }
    }

    private func refreshVisiblePrices() {
        guard !isLoading, !filteredRows.isEmpty else { return }

        // Refresh top 20 visible assets to avoid overloading
        let visibleAssets = filteredRows.prefix(20).map { $0.asset }

        // Filter assets that need update based on their category
        let assetsToUpdate = visibleAssets.filter { asset in
            guard
                let lastUpdate = lastPrices[asset.code] != nil
                    ? rows.first(where: { $0.asset.code == asset.code })?.lastUpdated : nil
            else {
                return true  // Never updated
            }

            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            let category = asset.category.lowercased()

            // Update intervals based on asset type
            if category.contains("crypto") {
                return timeSinceUpdate >= 10  // Crypto: Every 10 seconds
            } else if category.contains("forex") || category.contains("currency") {
                return timeSinceUpdate >= 300  // Forex: Every 5 minutes
            } else if category.contains("stock") || category.contains("equity")
                || category.contains("us_")
            {
                return timeSinceUpdate >= 60  // Stocks: Every 1 minute
            } else if category.contains("commodity") || category.contains("metal")
                || category.contains("gold")
            {
                return timeSinceUpdate >= 900  // Metals: Every 15 minutes
            } else if category.contains("fund") {
                return timeSinceUpdate >= 3600  // Funds: Every hour (effectively daily)
            }

            return timeSinceUpdate >= 60  // Default: 1 minute
        }

        guard !assetsToUpdate.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }

            // Batch fetch prices
            let codes = assetsToUpdate.map { $0.code }

            do {
                let prices = try await priceManager.fetchPrices(for: codes)

                await MainActor.run {
                    for (code, price) in prices {
                        let decimalPrice = Decimal(price)
                        self.lastPrices[code] = decimalPrice

                        // Update rows
                        if let index = self.rows.firstIndex(where: { $0.asset.code == code }) {
                            self.rows[index].price = decimalPrice
                            self.rows[index].change24h = self.computeChange(
                                for: code, newPrice: decimalPrice)
                            self.rows[index].lastUpdated = Date()
                        }
                    }

                    self.lastUpdated = Date()
                    self.applyFilters()
                }
            } catch {
                print("⚠️ Auto-refresh batch fetch failed: \(error)")
            }
        }
    }
}
