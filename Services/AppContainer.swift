import Combine
import CoreData
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let coreDataStack: CoreDataStack
    let settingsManager: SettingsManager
    let assetRepository: AssetRepository
    let plansRepository: PlansRepository
    let scenariosRepository: ScenariosRepository
    let planScheduler: PlanReminderScheduler
    let assetSeeder: CoreDataSeeder
    let assetSyncService: CoinGeckoAssetSyncService
    let priceManager: UnifiedPriceManager
    private var assetCatalogCancellable: AnyCancellable?

    init(mockMode: Bool = true) {
        coreDataStack = CoreDataStack.shared
        settingsManager = SettingsManager.shared
        assetRepository = AssetRepository(context: coreDataStack.viewContext)
        plansRepository = PlansRepository(context: coreDataStack.viewContext)
        scenariosRepository = ScenariosRepository(context: coreDataStack.viewContext)
        planScheduler = PlanReminderScheduler(
            repository: plansRepository,
            notificationManager: NotificationManager.shared,
            messageProvider: DefaultMotivationMessageProvider()
        )
        assetSeeder = CoreDataSeeder(
            context: coreDataStack.viewContext,
            assetRepository: assetRepository
        )
        assetSyncService = CoinGeckoAssetSyncService(repository: assetRepository)
        priceManager = UnifiedPriceManager.shared

        assetSeeder.seedAssetsIfNeeded()
        AssetCatalog.shared.update(with: assetRepository.fetchAllActive())
        assetCatalogCancellable = assetRepository.$activeAssets
            .receive(on: RunLoop.main)
            .sink { definitions in
                AssetCatalog.shared.update(with: definitions)
            }
        planScheduler.refreshSchedules()
    }
}

private struct AppContainerKey: EnvironmentKey {
    @MainActor static var defaultValue: AppContainer {
        AppContainer(mockMode: true)
    }
}

extension EnvironmentValues {
    var _appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
