import Combine
import Foundation

@MainActor
final class AssetManagementViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var displayName: String = ""
    @Published var symbol: String = ""
    @Published var selectedCategory: AssetCategory = .us_stock
    @Published var currency: String = "USD"
    @Published var logoURL: String = ""
    @Published var isActive: Bool = true
    @Published var externalId: String = ""
    @Published var coingeckoIdentifier: String = ""
    @Published var isSyncing = false
    @Published var assets: [AssetDefinition] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let repository: AssetRepository
    private let seeder: CoreDataSeeder?
    private let syncService: CoinGeckoAssetSyncService?
    private var cancellables = Set<AnyCancellable>()

    init(
        repository: AssetRepository, seeder: CoreDataSeeder? = nil,
        syncService: CoinGeckoAssetSyncService? = nil
    ) {
        self.repository = repository
        self.seeder = seeder
        self.syncService = syncService
        assets = repository.fetchAllActive()
        repository.$activeAssets
            .receive(on: RunLoop.main)
            .sink { [weak self] definitions in
                self?.assets = definitions
            }
            .store(in: &cancellables)
    }

    var canSave: Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseReady = !trimmedCode.isEmpty && !trimmedName.isEmpty
        guard baseReady else { return false }
        if inferredProvider == .coingecko {
            return !coingeckoIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    func saveAssetDefinition() {
        errorMessage = nil
        successMessage = nil

        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedLogo = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCode.isEmpty else {
            errorMessage = "Kod alanı boş olamaz."
            return
        }

        guard !trimmedName.isEmpty else {
            errorMessage = "Varlık adı boş olamaz."
            return
        }

        guard !trimmedCurrency.isEmpty else {
            errorMessage = "Para birimi boş olamaz."
            return
        }

        let dto = AssetDTO(
            code: trimmedCode,
            displayName: trimmedName,
            symbol: trimmedSymbol.isEmpty ? trimmedCode : trimmedSymbol,
            category: selectedCategory.rawValue,
            currency: trimmedCurrency,
            logoURL: trimmedLogo.isEmpty ? nil : trimmedLogo,
            isActive: isActive,
            providerType: inferredProvider,
            externalId: externalId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : externalId.trimmingCharacters(in: .whitespacesAndNewlines),
            coingeckoId: coingeckoIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : coingeckoIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        repository.addOrUpdate(from: dto)
        successMessage = "\(trimmedCode) kaydedildi."
        resetForm()
    }

    func importDefaultAssets() {
        guard let seeder else {
            errorMessage = "Varsayılan veri kaynağı bulunamadı."
            return
        }
        seeder.seedAssetsIfNeeded(force: true)
        successMessage = "Varsayılan varlıklar yüklendi."
    }

    func syncFromCoinGecko(limit: Int = 200) async {
        guard let syncService else {
            await MainActor.run { self.errorMessage = "Senkronizasyon servisi erişilemiyor." }
            return
        }
        await MainActor.run {
            self.isSyncing = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        do {
            try await syncService.syncTopCoins(limit: limit)
            await MainActor.run {
                self.successMessage = "CoinGecko listesi güncellendi."
                self.isSyncing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isSyncing = false
            }
        }
    }

    private func resetForm() {
        code = ""
        displayName = ""
        symbol = ""
        selectedCategory = .us_stock
        currency = "TRY"
        logoURL = ""
        isActive = true
        externalId = ""
        coingeckoIdentifier = ""
    }

    private var inferredProvider: AssetProviderType {
        selectedCategory == .crypto ? .coingecko : .unknown
    }
}
