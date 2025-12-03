import Combine
import CoreData
import Foundation
import OSLog
import SwiftUI

// MARK: - Minimal ViewModel to satisfy UI
final class DCASimulationVM: ObservableObject {
    enum SimulationState {
        case idle
        case ready
        case running
        case completed
    }

    @Published var config: ScenarioConfig
    @Published var isRunning = false
    @Published var result: SimulationResult? = nil
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var transactions: [Transaction] = []
    @Published private(set) var simulationState: SimulationState = .idle
    @Published private(set) var lastRunConfig: ScenarioConfig? = nil
    @Published var priceLoadingMessage: String? = nil

    private let engine = DCAEngine()
    private let logger = Logger(subsystem: "InvestSimulator", category: "DCASimulation")
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        return calendar
    }()
    private var scenariosRepository: ScenariosRepository?
    private var assetRepository: AssetRepository?
    private var priceManager: UnifiedPriceManager?
    private var simulationTask: Task<Void, Never>? = nil

    init() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2022
        components.month = 1
        components.day = 1
        let start = components.date ?? Date()
        let end = Date()
        self.config = ScenarioConfig(
            name: "",
            initialInvestment: 0,
            monthlyInvestment: 0,
            investmentCurrency: .USD,
            startDate: start,
            endDate: end,
            interval: .month,
            frequency: 1,
            slippage: 0,
            transactionFee: 0,
            assetAllocations: []
        )
        evaluateSimulationReadiness()
    }

    deinit {
        simulationTask?.cancel()
    }

    var bindingStartDate: Binding<Date> {
        Binding(
            get: { self.config.startDate },
            set: { self.setStartDate($0) }
        )
    }

    var bindingEndDate: Binding<Date> {
        Binding(
            get: { self.config.endDate },
            set: { self.setEndDate($0) }
        )
    }

    func updateName(_ name: String) {
        clearResultsIfNeeded()
        config.name = name
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func updateInitialInvestment(_ value: Decimal) {
        clearResultsIfNeeded()
        config.initialInvestment = value
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func updateMonthlyInvestment(_ value: Decimal) {
        clearResultsIfNeeded()
        config.monthlyInvestment = value
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func updateInterval(_ interval: Calendar.Component) {
        clearResultsIfNeeded()
        config.interval = interval

        switch interval {
        case .weekOfMonth:
            config.frequency = min(max(1, config.frequency), 7)
        case .month:
            config.frequency = min(max(1, config.frequency), 12)
        default:
            config.frequency = max(1, config.frequency)
        }

        config.customDaysOfMonth = nil

        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func updateFrequency(_ value: Int) {
        clearResultsIfNeeded()

        let clamped: Int
        switch config.interval {
        case .weekOfMonth:
            clamped = min(max(1, value), 7)
        case .month:
            clamped = min(max(1, value), 12)
        default:
            clamped = max(1, value)
        }

        config.frequency = clamped
        if var days = config.customDaysOfMonth {
            days = Array(Set(days)).sorted()
            config.customDaysOfMonth = Array(days.prefix(clamped))
        }

        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func updateInvestmentCurrency(_ code: AssetCode) {
        clearResultsIfNeeded()
        config.investmentCurrency = code
        objectWillChange.send()
        evaluateSimulationReadiness()
    }

    func addAsset(_ code: AssetCode, weight: Decimal) {
        clearResultsIfNeeded()
        config.addAsset(code, weight: weight)
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func removeAsset(_ code: AssetCode) {
        clearResultsIfNeeded()
        config.removeAsset(code)
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func updateAssetWeight(_ code: AssetCode, weight: Decimal) {
        clearResultsIfNeeded()
        config.updateAssetWeight(code, weight: weight)
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func resetAllWeights() {
        clearResultsIfNeeded()
        config.resetAllWeights()
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func distributeWeightsEqually() {
        clearResultsIfNeeded()
        config.distributeWeightsEqually()
        objectWillChange.send()
        evaluateSimulationReadiness()
    }
    func fillRemainingEvenly() {
        clearResultsIfNeeded()
        config.fillRemainingEvenly()
        objectWillChange.send()
        evaluateSimulationReadiness()
    }

    func updateCustomDays(_ days: [Int]?) {
        clearResultsIfNeeded()

        guard let days else {
            config.customDaysOfMonth = nil
            objectWillChange.send()
            evaluateSimulationReadiness()
            return
        }

        let sanitized: [Int]
        switch config.interval {
        case .weekOfMonth:
            sanitized = Array(
                Set(days.filter { (1...7).contains($0) })
                    .sorted()
                    .prefix(config.frequency)
            )
        case .month:
            sanitized = Array(
                Set(days.filter { (1...31).contains($0) })
                    .sorted()
                    .prefix(config.frequency)
            )
        default:
            sanitized = Array(Set(days).sorted().prefix(config.frequency))
        }

        config.customDaysOfMonth = sanitized.isEmpty ? nil : sanitized
        objectWillChange.send()
        evaluateSimulationReadiness()
    }

    func setStartDate(_ date: Date) {
        clearResultsIfNeeded()
        config.startDate = date
        objectWillChange.send()
        evaluateSimulationReadiness()
    }

    func setEndDate(_ date: Date) {
        clearResultsIfNeeded()
        config.endDate = date
        objectWillChange.send()
        evaluateSimulationReadiness()
    }

    func applyConfiguration(_ newConfig: ScenarioConfig) {
        clearResultsIfNeeded()
        config = newConfig
        objectWillChange.send()
        evaluateSimulationReadiness()
    }

    func attach(repository: ScenariosRepository) {
        scenariosRepository = repository
        evaluateSimulationReadiness()
    }

    func configure(with container: AppContainer) {
        scenariosRepository = container.scenariosRepository
        assetRepository = container.assetRepository
        priceManager = container.priceManager
        evaluateSimulationReadiness()
    }

    private let templatesKey = "dca_templates_v1"
    func templateNames() -> [String] {
        let dict = UserDefaults.standard.dictionary(forKey: templatesKey) as? [String: Data] ?? [:]
        return dict.keys.sorted()
    }
    func saveTemplate(named name: String) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        var dict = UserDefaults.standard.dictionary(forKey: templatesKey) as? [String: Data] ?? [:]
        dict[name] = data
        UserDefaults.standard.set(dict, forKey: templatesKey)
        successMessage = "Template saved"
    }
    func loadTemplate(named name: String) {
        guard let dict = UserDefaults.standard.dictionary(forKey: templatesKey) as? [String: Data],
            let data = dict[name],
            let loaded = try? JSONDecoder().decode(ScenarioConfig.self, from: data)
        else { return }
        applyConfiguration(loaded)
    }

    func handlePrimaryAction() {
        switch simulationState {
        case .running:
            return
        case .completed:
            resetSimulation()
        case .ready:
            runSimulation()
        case .idle:
            evaluateSimulationReadiness()
            if simulationState != .ready {
                let requiredDays = max(1, config.frequency)
                let selectedDays = config.customDaysOfMonth?.count ?? 0
                if selectedDays != requiredDays {
                    let dayMessage =
                        requiredDays == 1
                        ? "You must select a day to start the simulation."
                        : String(
                            format: NSLocalizedString(
                                "You must select %d days to start the simulation.", comment: ""),
                            requiredDays)
                    errorMessage = dayMessage
                } else {
                    errorMessage =
                        "Ensure 100% distribution and positive investment amounts to start."
                }
            }
        }
    }

    var primaryButtonTitle: String {
        switch simulationState {
        case .running:
            return "Simulation Running..."
        case .completed:
            return "Restart"
        default:
            return "Start Simulation"
        }
    }

    var primaryButtonIcon: String? {
        switch simulationState {
        case .running:
            return nil
        case .completed:
            return "arrow.clockwise"
        default:
            return "play.circle.fill"
        }
    }

    var isPrimaryButtonEnabled: Bool {
        switch simulationState {
        case .ready, .completed:
            return true
        default:
            return false
        }
    }

    func runSimulation() {
        evaluateSimulationReadiness()
        guard simulationState == .ready else {
            errorMessage = "Requirements for simulation not met."
            return
        }
        guard !isRunning else { return }
        guard let priceManager else {
            errorMessage = "Price service is not ready."
            return
        }
        guard let assetRepository else {
            errorMessage = "Asset information unavailable."
            return
        }

        errorMessage = nil
        successMessage = nil
        result = nil
        transactions.removeAll()

        guard let snapshot = makeConfigSnapshot() else {
            errorMessage = "Scenario data could not be prepared."
            simulationState = .idle
            isRunning = false
            evaluateSimulationReadiness()
            return
        }

        simulationTask?.cancel()
        isRunning = true
        simulationState = .running
        priceLoadingMessage = "Loading price data..."

        simulationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let provider = try await self.preparePriceProvider(
                    for: snapshot,
                    priceManager: priceManager,
                    assetRepository: assetRepository
                )
                await MainActor.run {
                    self.priceLoadingMessage = nil
                }

                let simulationResult = try await Task.detached(priority: .userInitiated) {
                    try self.engine.simulate(config: snapshot, provider: provider)
                }.value
                let preparedTransactions = self.buildTransactions(
                    from: simulationResult.deals, config: snapshot)

                await MainActor.run {
                    self.result = simulationResult
                    self.transactions = preparedTransactions
                    self.successMessage = NSLocalizedString(
                        "Simulation completed", comment: "")
                    self.isRunning = false
                    self.simulationState = .completed
                    self.lastRunConfig = snapshot
                    self.persistScenario(config: snapshot, result: simulationResult)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isRunning = false
                    self.simulationState = .idle
                    self.priceLoadingMessage = nil
                    self.evaluateSimulationReadiness()
                }
            } catch {
                self.logger.error(
                    "DCA simulation failed: \(error.localizedDescription, privacy: .public)")
                let message = self.message(for: error)
                await MainActor.run {
                    self.errorMessage = message
                    self.isRunning = false
                    self.simulationState = .idle
                    self.priceLoadingMessage = nil
                    self.evaluateSimulationReadiness()
                }
            }
        }
    }

    func resetSimulation() {
        simulationTask?.cancel()
        result = nil
        transactions.removeAll()
        successMessage = nil
        errorMessage = nil
        isRunning = false
        simulationState = .idle
        lastRunConfig = nil
        priceLoadingMessage = nil
        evaluateSimulationReadiness()
    }

    private func makeConfigSnapshot() -> ScenarioConfig? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(config)
            return try decoder.decode(ScenarioConfig.self, from: data)
        } catch {
            logger.error("Config snapshot failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func evaluateSimulationReadiness() {
        guard !isRunning else { return }

        let hasAssets = config.assetAllocations.contains { $0.isEnabled && $0.weight > 0 }
        let weightsValid = config.isValidWeightDistribution
        let hasInvestment = config.initialInvestment > 0 || config.monthlyInvestment > 0
        let datesValid = config.startDate < config.endDate
        let requiredDays = max(1, config.frequency)
        let selectedDays = config.customDaysOfMonth?.count ?? 0

        let needsDaySelection = config.interval == .weekOfMonth || config.interval == .month
        let hasValidDaySelection = needsDaySelection ? (selectedDays == requiredDays) : true

        if hasAssets && weightsValid && hasInvestment && datesValid && hasValidDaySelection {
            simulationState = .ready
        } else {
            simulationState = .idle
        }
    }

    private func preparePriceProvider(
        for config: ScenarioConfig,
        priceManager: UnifiedPriceManager,
        assetRepository: AssetRepository
    ) async throws -> DCAProvider {
        let uniqueCodes = Set(config.assetAllocations.map { $0.assetCode })
        var history: [String: [Date: Decimal]] = [:]
        var latest: [String: Decimal] = [:]
        await MainActor.run {
            self.priceLoadingMessage =
                "Downloading historical price data for this asset (first use)."
        }

        for code in uniqueCodes {
            guard let definition = assetRepository.fetch(byCode: code.rawValue) else {
                throw SimulationPreparationError.missingAssetDefinition(code.rawValue)
            }
            // Removed provider restriction to support Yahoo and Metals
            // guard definition.provider == .coingecko else {
            //    throw SimulationPreparationError.unsupportedProvider(definition.displayName)
            // }

            // For CoinGecko, we need an ID. For others, we might rely on symbol.
            if definition.provider == .coingecko {
                guard (definition.coingeckoId ?? definition.externalId) != nil else {
                    throw SimulationPreparationError.missingIdentifier(definition.displayName)
                }
            }

            await MainActor.run {
                self.priceLoadingMessage = String(
                    format: "Loading price data... %@",
                    definition.displayName)
            }

            let series = try await priceManager.historicalPrices(
                for: definition,
                start: config.startDate,
                end: config.endDate
            )
            guard !series.isEmpty else {
                throw SimulationPreparationError.historicalDataUnavailable(definition.displayName)
            }

            var map: [Date: Decimal] = [:]
            let ordered = series.sorted { $0.updatedAt < $1.updatedAt }
            for entry in ordered {
                let normalized = calendar.startOfDay(for: entry.updatedAt)
                map[normalized] = entry.price
            }
            history[code.symbol] = map
            if let last = ordered.last {
                latest[code.symbol] = last.price
            }
        }

        return HistoricalPriceProvider(history: history, latest: latest)
    }

    private func clearResultsIfNeeded() {
        guard simulationState == .completed else { return }
        result = nil
        transactions.removeAll()
        successMessage = nil
        errorMessage = nil
        priceLoadingMessage = nil
        simulationState = .idle
        lastRunConfig = nil
        evaluateSimulationReadiness()
    }

    private func persistScenario(config: ScenarioConfig, result: SimulationResult) {
        scenariosRepository?.addScenario(config: config, result: result)
    }

    private func message(for error: Error) -> String {
        if let preparationError = error as? SimulationPreparationError {
            return preparationError.errorDescription ?? "Price data could not be loaded."
        }
        if let priceError = error as? UnifiedPriceError {
            switch priceError {
            case .unsupportedAsset:
                return "This asset is currently not supported."
            case .noProviderAvailable:
                return "Price provider is unavailable."
            case .networkError:
                return "Check your internet connection."
            case .cacheError:
                return "Could not read price cache."
            case .missingIdentifier:
                return "Missing identifier for this asset."
            case .historicalDataUnavailable:
                return "Historical price data not found."
            }
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Simulation could not start: \(error.localizedDescription)"
    }

    private func buildTransactions(from deals: [DealLog], config: ScenarioConfig) -> [Transaction] {
        let activeDeals = deals.filter { !$0.skipped && $0.spentTRY > 0 }
        guard !activeDeals.isEmpty else { return [] }

        let groups = Dictionary(grouping: activeDeals) { calendar.startOfDay(for: $0.date) }
        let sortedDates = groups.keys.sorted(by: >)
        let initialDate = calendar.startOfDay(for: config.startDate)

        return sortedDates.compactMap { date -> Transaction? in
            guard let entries = groups[date] else { return nil }
            let totalAmount = entries.reduce(Decimal(0)) { $0 + $1.spentTRY }.rounded(scale: 2)
            let distribution = buildAssetTransactions(from: entries, totalAmount: totalAmount)
            guard !distribution.isEmpty else { return nil }
            let type: TransactionType =
                (config.initialInvestment > 0 && calendar.isDate(date, inSameDayAs: initialDate))
                ? .initial : .monthly
            return Transaction(
                date: date, totalAmount: totalAmount, distribution: distribution, type: type)
        }
    }

    private func buildAssetTransactions(from deals: [DealLog], totalAmount: Decimal)
        -> [AssetTransaction]
    {
        guard !deals.isEmpty else { return [] }

        let validDeals = deals.compactMap { deal -> (AssetCode, DealLog)? in
            guard let code = assetCode(for: deal.symbol) else { return nil }
            return (code, deal)
        }

        var items: [AssetTransaction] = []
        var accumulatedPercentage: Decimal = 0

        for (index, pair) in validDeals.enumerated() {
            let (code, deal) = pair
            let amount = deal.spentTRY.rounded(scale: 2)
            let units = deal.units.rounded(scale: 6)
            let price = deal.price.rounded(scale: 2)

            let computedShare =
                totalAmount.isZero
                ? Decimal.zero : ((deal.spentTRY / totalAmount) * 100).rounded(scale: 1)
            let percentage: Decimal
            if index == validDeals.count - 1 {
                let remaining = (100 - accumulatedPercentage).rounded(scale: 1)
                percentage = max(Decimal.zero, remaining)
            } else {
                let clamped = min(max(computedShare, 0), 100)
                percentage = clamped
                accumulatedPercentage += percentage
                accumulatedPercentage = min(accumulatedPercentage, 100)
            }

            let transaction = AssetTransaction(
                assetCode: code,
                amountTRY: amount,
                percentage: percentage,
                units: units,
                unitPriceTRY: price
            )
            items.append(transaction)
        }

        return items.sorted { $0.amountTRY > $1.amountTRY }
    }

    private func assetCode(for symbol: String) -> AssetCode? {
        AssetCode.allCases.first(where: { code in
            code.symbol.caseInsensitiveCompare(symbol) == .orderedSame
                || code.rawValue.caseInsensitiveCompare(symbol) == .orderedSame
        })
    }
}

private enum SimulationPreparationError: LocalizedError {
    case missingAssetDefinition(String)
    case unsupportedProvider(String)
    case missingIdentifier(String)
    case historicalDataUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingAssetDefinition(let code):
            return String(
                format: "Asset record not found: %@", code)
        case .unsupportedProvider(let name):
            return String(
                format: "Data provider for %@ is not supported yet.", name
            )
        case .missingIdentifier(let name):
            return String(
                format: "CoinGecko ID not defined for %@.", name)
        case .historicalDataUnavailable(let name):
            return String(
                format: "Historical price data not found for %@.", name)
        }
    }
}
// MARK: - Simple Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(
                    Color.blue.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(configuration.isPressed ? 0.8 : 0.3), lineWidth: 1)
            )
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

/// DCA Simülasyon ana view'ı
/// Kullanıcının senaryo oluşturup çalıştırmasını ve sonuçları görmesini sağlar.
struct DCAScenarioView: View {
    @ObservedObject var viewModel: DCASimulationVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\._appContainer) private var container
    @State private var selectedCategory: AssetCategory = .crypto
    @State private var showingAssetPicker = false
    @State private var showingDayPicker = false
    @State private var showingTemplateSave = false
    @State private var templateName: String = ""
    @State private var initialInvestmentText: String
    @State private var monthlyInvestmentText: String
    @State private var initialInvestmentError: String?
    @State private var monthlyInvestmentError: String?

    init(viewModel: DCASimulationVM? = nil) {
        let resolvedViewModel = viewModel ?? DCASimulationVM()
        self.viewModel = resolvedViewModel
        _initialInvestmentText = State(
            initialValue: Self.formatDecimal(resolvedViewModel.config.initialInvestment))
        _monthlyInvestmentText = State(
            initialValue: Self.formatDecimal(resolvedViewModel.config.monthlyInvestment))
        _initialInvestmentError = State(initialValue: nil)
        _monthlyInvestmentError = State(initialValue: nil)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    temelCard
                    siklikCard
                    allocationCard
                    actionButtons
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: viewModel.simulationState) { _, state in
                if state == .completed {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Simulation Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("OK") { dismiss() }
                    .font(.body.weight(.semibold))
            }
        }
        .onAppear {
            viewModel.configure(with: container)
        }
        .sheet(isPresented: $showingAssetPicker) {
            AssetPickerView(
                selectedCategory: $selectedCategory,
                existingSelection: Set(viewModel.config.assetAllocations.map { $0.assetCode }),
                onConfirm: { codes in
                    Task { @MainActor in
                        for code in codes
                        where !viewModel.config.assetAllocations.contains(where: {
                            $0.assetCode == code
                        }) {
                            viewModel.addAsset(code, weight: 0)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingDayPicker) {
            DayPickerSheet(
                maxSelection: viewModel.config.frequency,
                initialSelection: viewModel.config.customDaysOfMonth ?? [],
                onDone: { days in
                    Task { @MainActor in
                        let limited = Array(days.sorted().prefix(viewModel.config.frequency))
                        viewModel.updateCustomDays(limited.isEmpty ? nil : limited)
                    }
                }
            )
        }
        .sheet(isPresented: $showingTemplateSave) {
            TemplateSaveSheet(name: $templateName) { name in
                viewModel.saveTemplate(named: name)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var unitLabel: String {
        switch viewModel.config.interval {
        case .day: return "Day"
        case .weekOfMonth: return "Week"
        case .month: return "Month"
        default: return "Period"
        }
    }

    // MARK: - Demo Portfolio Creation

    private func createDemoPortfolio() {
        let existingCodes = viewModel.config.assetAllocations.map { $0.assetCode }
        existingCodes.forEach { viewModel.removeAsset($0) }

        let demoAllocations: [(AssetCode, Decimal)] = [
            (.BTC, 0.4),
            (.ETH, 0.3),
            (.MATIC, 0.2),
            (.SOL, 0.1),
        ]

        demoAllocations.forEach { code, weight in
            viewModel.addAsset(code, weight: weight)
        }
    }

    private func createConservativePortfolio() {
        // Konservatif portföy: Düşük risk, düşük getiri
        let existingCodes = viewModel.config.assetAllocations.map { $0.assetCode }
        existingCodes.forEach { viewModel.removeAsset($0) }

        let conservative: [(AssetCode, Decimal)] = [
            (.BTC, 0.4),
            (.ETH, 0.3),
            (.BNB, 0.2),
            (.ADA, 0.1),
        ]

        conservative.forEach { viewModel.addAsset($0, weight: $1) }
    }

    private func createAggressivePortfolio() {
        // Agresif portföy: Yüksek risk, yüksek getiri
        let existingCodes = viewModel.config.assetAllocations.map { $0.assetCode }
        existingCodes.forEach { viewModel.removeAsset($0) }

        let aggressive: [(AssetCode, Decimal)] = [
            (.BTC, 0.4),
            (.ETH, 0.3),
            (.SOL, 0.15),
            (.AVAX, 0.15),
        ]

        aggressive.forEach { viewModel.addAsset($0, weight: $1) }
    }

    private func runQuickTest() {
        // Set default values for quick test
        viewModel.updateName("Quick Test - \(DateFormatter.shortDate.string(from: Date()))")
        viewModel.updateInitialInvestment(1000)
        viewModel.updateMonthlyInvestment(500)
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        viewModel.setStartDate(start)
        viewModel.setEndDate(Date())
        viewModel.updateInterval(.month)
        viewModel.updateFrequency(1)
        viewModel.updateCustomDays([1])

        // Demo portföy oluştur
        createDemoPortfolio()

        // Simülasyonu başlat
        viewModel.runSimulation()
    }
}

// MARK: - Compact Allocation Row
// MARK: - Asset Picker View

struct AssetPickerView: View {
    @Binding var selectedCategory: AssetCategory
    let existingSelection: Set<AssetCode>
    let onConfirm: ([AssetCode]) -> Void
    @Environment(\.dismiss) private var dismiss

    private let assetHelper = AssetSelectionHelper.shared
    @State private var searchText: String = ""
    @State private var pendingSelection: Set<AssetCode> = []

    private var availableCategories: [AssetCategory] {
        AssetCategory.allCases.filter { !assetHelper.getAssetsByCategory($0).isEmpty }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(availableCategories, id: \.self) { category in
                        Label(category.displayName, systemImage: category.icon).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .onAppear {
                    if !availableCategories.contains(selectedCategory) {
                        selectedCategory = availableCategories.first ?? .crypto
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search assets...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 20)

                if !pendingSelection.isEmpty {
                    Text("\(pendingSelection.count) assets selected")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                }

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredAssets) { asset in
                            let code = asset.assetCode
                            let disabled = existingSelection.contains(code)
                            let selected = pendingSelection.contains(code)
                            Button {
                                guard !disabled else { return }
                                if selected {
                                    pendingSelection.remove(code)
                                } else {
                                    pendingSelection.insert(code)
                                }
                            } label: {
                                AssetPickerRow(
                                    asset: asset, isSelected: selected, isDisabled: disabled)
                            }
                            .buttonStyle(.plain)
                            .disabled(disabled)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .background(Color.clear)
            }
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onConfirm(Array(pendingSelection))
                        dismiss()
                    }
                    .disabled(pendingSelection.isEmpty)
                }
            }
            .onAppear {
                pendingSelection.removeAll()
            }
        }
    }

    private var filteredAssets: [SelectableAsset] {
        let list = assetHelper.getAssetsByCategory(selectedCategory)
        guard !searchText.isEmpty else { return list }
        let q = searchText.lowercased()
        return list.filter {
            $0.displayName.lowercased().contains(q) || $0.symbol.lowercased().contains(q)
        }
    }
}

private struct AssetPickerRow: View {
    let asset: SelectableAsset
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primaryBlue.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: asset.category.icon)
                    .foregroundColor(isDisabled ? .secondary : .primaryBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isDisabled ? .secondary : .primary)
                Text(asset.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Group {
                if isDisabled {
                    Image(systemName: "lock.fill")
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                }
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(isDisabled ? .secondary : (isSelected ? .accentColor : .secondary))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
        )
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Inline Simulation Results
private struct InlineSimulationResultsView: View {
    let result: SimulationResult?
    let transactions: [Transaction]

    var body: some View {
        VStack(spacing: 16) {
            summaryCard

            if !transactions.isEmpty {
                ResultsDisclosure(transactions: transactions, result: result)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: result?.id)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Simulation Results")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                if let result {
                    Text(Self.dateFormatter.string(from: result.simulationDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let result {
                metricsStack(for: result)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ready?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(
                            "Set parameters and click \"Start Simulation\" to test your strategy."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private func resultMetrics(for result: SimulationResult) -> [ResultMetric] {
        let profitTint: Color
        if result.profitTRY > 0 {
            profitTint = .green
        } else if result.profitTRY < 0 {
            profitTint = .red
        } else {
            profitTint = .primary
        }

        return [
            ResultMetric(
                title: "Total Investment",
                value: result.investedTotalFormatted,
                icon: "creditcard.fill",
                tint: .blue,
                usesNeutralValueColor: true
            ),
            ResultMetric(
                title: "Total Return",
                value: result.profitTRYFormatted,
                icon: result.profitTRY >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                tint: profitTint,
                usesNeutralValueColor: result.profitTRY == 0
            ),
            ResultMetric(
                title: "ROI",
                value: result.profitPctFormatted,
                icon: "percent",
                tint: profitTint,
                usesNeutralValueColor: result.profitTRY == 0
            ),
            ResultMetric(
                title: "Portfolio Value",
                value: result.currentValueFormatted,
                icon: "wallet.pass.fill",
                tint: .purple,
                usesNeutralValueColor: false
            ),
            ResultMetric(
                title: "Transaction Count",
                value: "\(result.totalDealsCount)",
                icon: "tray.full.fill",
                tint: Color(hex: "#14B8A6"),
                usesNeutralValueColor: false
            ),
        ]
    }

    private func metricsStack(for result: SimulationResult) -> some View {
        let metrics = resultMetrics(for: result)
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                MetricRow(metric: metric)
                if index < metrics.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}

private struct ResultMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let usesNeutralValueColor: Bool
}

private struct MetricRow: View {
    let metric: ResultMetric

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(metric.tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: metric.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(metric.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(metric.value)
                    .font(.body.weight(.semibold))
                    .foregroundColor(metric.usesNeutralValueColor ? .primary : metric.tint)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Frequency Picker View
private struct FrequencyPickerView: View {
    @Binding var interval: Calendar.Component
    @Binding var frequency: Int
    @Binding var customDays: [Int]
    let onPickDays: () -> Void

    private let intervalOptions: [Calendar.Component] = [.weekOfMonth, .month]

    private struct WeekdayOption: Identifiable {
        let id = UUID()
        let index: Int
        let shortTitle: String
        let fullTitle: String
    }

    private let weekOptions: [WeekdayOption] = [
        WeekdayOption(index: 1, shortTitle: "Mon", fullTitle: "Monday"),
        WeekdayOption(index: 2, shortTitle: "Tue", fullTitle: "Tuesday"),
        WeekdayOption(index: 3, shortTitle: "Wed", fullTitle: "Wednesday"),
        WeekdayOption(index: 4, shortTitle: "Thu", fullTitle: "Thursday"),
        WeekdayOption(index: 5, shortTitle: "Fri", fullTitle: "Friday"),
        WeekdayOption(index: 6, shortTitle: "Sat", fullTitle: "Saturday"),
        WeekdayOption(index: 7, shortTitle: "Sun", fullTitle: "Sunday"),
    ]

    init(
        interval: Binding<Calendar.Component>,
        frequency: Binding<Int>,
        customDays: Binding<[Int]>,
        onPickDays: @escaping () -> Void
    ) {
        self._interval = interval
        self._frequency = frequency
        self._customDays = customDays
        self.onPickDays = onPickDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Period", selection: $interval) {
                ForEach(intervalOptions, id: \.self) { option in
                    Text(label(for: option)).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if interval == .weekOfMonth {
                weeklyControls
            } else {
                monthlyControls
            }

            Text(secondaryHint)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onChange(of: interval) { _, _ in
            let clamped = clampFrequency(frequency)
            if clamped != frequency {
                DispatchQueue.main.async {
                    frequency = clamped
                }
            }

            if !customDays.isEmpty {
                DispatchQueue.main.async {
                    customDays = []
                }
            }
        }
        .onChange(of: frequency) { _, newValue in
            let clamped = clampFrequency(newValue)
            if clamped != newValue {
                DispatchQueue.main.async {
                    frequency = clamped
                }
            }
        }
    }

    private var weeklyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(
                value: Binding(
                    get: { clampFrequency(frequency) },
                    set: { frequency = clampFrequency($0) }
                ), in: 1...7
            ) {
                HStack {
                    Text("Per Week")
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(frequency) times")
                        .font(.body.weight(.semibold))
                }
            }

            let selection = Set(customDays)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10
            ) {
                ForEach(weekOptions) { option in
                    let isSelected = selection.contains(option.index)
                    Button {
                        toggleWeekday(option.index, isSelected: isSelected)
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.shortTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(option.fullTitle)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    isSelected
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            let remaining = max(0, frequency - selection.count)
            if remaining > 0 {
                Text("Select \(remaining) more days")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
        }
    }

    private var monthlyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(
                value: Binding(
                    get: { clampFrequency(frequency) },
                    set: { frequency = clampFrequency($0) }
                ), in: 1...12
            ) {
                HStack {
                    Text("Per Month")
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(frequency) times")
                        .font(.body.weight(.semibold))
                }
            }

            Button(action: onPickDays) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("Select Days")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(frequency <= 0)

            if !customDays.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(customDays.sorted(), id: \.self) { day in
                            Text("\(day)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    private func toggleWeekday(_ index: Int, isSelected: Bool) {
        var selection = Set(customDays)
        if isSelected {
            selection.remove(index)
        } else {
            guard selection.count < frequency else { return }
            selection.insert(index)
        }
        customDays = selection.sorted()
    }

    private func secondaryHintText(for component: Calendar.Component) -> String {
        switch component {
        case .weekOfMonth:
            return
                "Weekly investments require day selection. Number of selected days must match frequency."
        case .month:
            return "For monthly plans, you must select as many days as specified."
        default:
            return ""
        }
    }

    private var secondaryHint: String {
        secondaryHintText(for: interval)
    }

    private func clampFrequency(_ value: Int) -> Int {
        let maxValue = interval == .weekOfMonth ? 7 : 12
        return min(max(1, value), maxValue)
    }

    private func label(for component: Calendar.Component) -> String {
        switch component {
        case .weekOfMonth: return "Weekly"
        case .month: return "Monthly"
        default: return "Other"
        }
    }
}

// MARK: - Parameters Card (split to reduce body complexity)
extension DCAScenarioView {
    fileprivate static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    fileprivate static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    fileprivate func formattedDate(_ date: Date) -> String {
        Self.longDateFormatter.string(from: date)
    }

    fileprivate static func formatDecimal(_ decimal: Decimal) -> String {
        Self.decimalFormatter.string(from: decimal as NSDecimalNumber) ?? ""
    }

    fileprivate func sanitizeNumericInput(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "0123456789,")
        var filteredScalars = value.unicodeScalars.filter { allowed.contains($0) }
        var sanitized = String(String.UnicodeScalarView(filteredScalars))

        let commaIndices = sanitized.indices.filter { sanitized[$0] == "," }
        if commaIndices.count > 1 {
            for index in commaIndices.dropFirst().reversed() {
                sanitized.remove(at: index)
            }
        }

        if sanitized.count > 12 {
            sanitized = String(sanitized.prefix(12))
        }

        return sanitized
    }

    fileprivate func handleInvestmentInput(
        _ text: inout String,
        error: inout String?,
        newValue: String,
        update: (Decimal) -> Void
    ) {
        let sanitized = sanitizeNumericInput(newValue)
        if sanitized != newValue {
            text = sanitized
            error = "Please enter numbers only."
        } else {
            text = sanitized
            error = nil
        }

        guard !sanitized.isEmpty else {
            update(0)
            return
        }

        if sanitized.last == "," {
            return
        }

        let normalized = sanitized.replacingOccurrences(of: ",", with: ".")
        if let decimal = Decimal(string: normalized) {
            update(decimal)
        }
    }

}

// MARK: - Grouped cards
extension DCAScenarioView {
    fileprivate var temelCard: some View {
        ModernCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Basic Parameters").font(.headline).foregroundColor(.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Scenario Name").font(.subheadline).foregroundColor(.textSecondary)
                    TextField(
                        "E.g: Bitcoin DCA Strategy",
                        text: Binding(
                            get: { viewModel.config.name },
                            set: { viewModel.updateName($0) }
                        )
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date").font(.subheadline).foregroundColor(.textSecondary)
                        Text(formattedDate(viewModel.config.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker(
                            "", selection: viewModel.bindingStartDate, in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "en_US"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Date").font(.subheadline).foregroundColor(.textSecondary)
                        Text(formattedDate(viewModel.config.endDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker(
                            "", selection: viewModel.bindingEndDate,
                            in: viewModel.config.startDate..., displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "en_US"))
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Initial Investment").font(.subheadline).foregroundColor(
                            .textSecondary)
                        HStack {
                            Text(viewModel.config.investmentCurrency.symbol).foregroundColor(
                                .textSecondary)
                            TextField("0,00", text: $initialInvestmentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .onChange(of: initialInvestmentText) { _, newValue in
                                    handleInvestmentInput(
                                        &initialInvestmentText, error: &initialInvestmentError,
                                        newValue: newValue
                                    ) { decimal in
                                        viewModel.updateInitialInvestment(decimal)
                                    }
                                }
                        }
                        if let message = initialInvestmentError {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Investment").font(.subheadline).foregroundColor(
                            .textSecondary)
                        HStack {
                            Text(viewModel.config.investmentCurrency.symbol).foregroundColor(
                                .textSecondary)
                            TextField("0,00", text: $monthlyInvestmentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .onChange(of: monthlyInvestmentText) { _, newValue in
                                    handleInvestmentInput(
                                        &monthlyInvestmentText, error: &monthlyInvestmentError,
                                        newValue: newValue
                                    ) { decimal in
                                        viewModel.updateMonthlyInvestment(decimal)
                                    }
                                }
                        }
                        if let message = monthlyInvestmentError {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency").font(.subheadline).foregroundColor(.textSecondary)
                    Picker(
                        "Currency",
                        selection: Binding(
                            get: { viewModel.config.investmentCurrency },
                            set: { viewModel.updateInvestmentCurrency($0) }
                        )
                    ) {
                        ForEach(AssetCode.allCases.filter { $0.assetType == .forex }, id: \.self) {
                            currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
        }
    }

    fileprivate var siklikCard: some View {
        ModernCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Investment Frequency").font(.headline).foregroundColor(.textPrimary)
                FrequencyPickerView(
                    interval: Binding(
                        get: { viewModel.config.interval }, set: { viewModel.updateInterval($0) }),
                    frequency: Binding(
                        get: { viewModel.config.frequency }, set: { viewModel.updateFrequency($0) }),
                    customDays: Binding(
                        get: { viewModel.config.customDaysOfMonth ?? [] },
                        set: { viewModel.updateCustomDays($0.isEmpty ? nil : $0) }),
                    onPickDays: { showingDayPicker = true }
                )
                // Min tarih aralığı uyarısı
                let months =
                    Calendar.current.dateComponents(
                        [.month], from: viewModel.config.startDate, to: viewModel.config.endDate
                    ).month ?? 0
                if months < 3 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("Date range is too short. Must be at least 3 months.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                // Şablon işlemleri
                HStack(spacing: 12) {
                    Button("Save Template") {
                        templateName = viewModel.config.name
                        showingTemplateSave = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 40)

                    Menu {
                        let names = viewModel.templateNames()
                        if names.isEmpty {
                            Text("No saved templates")
                        } else {
                            ForEach(names, id: \.self) { n in
                                Button(n) { viewModel.loadTemplate(named: n) }
                            }
                        }
                    } label: {
                        Text("Load from Template")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .padding()
        }
    }
}

// MARK: - Allocation / Actions / Results split
extension DCAScenarioView {
    fileprivate var allocationCard: some View {
        ModernCard(style: .outlined) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Asset Allocation")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: { showingAssetPicker = true }) {
                        Label("Add Asset", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primaryBlue.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }

                AllocationSummaryCard(
                    totalPercent: Double(viewModel.config.totalWeightPercentage.doubleValue))

                AllocationButtonsBar(
                    isDisabled: viewModel.config.assetAllocations.isEmpty,
                    onEqualize: { viewModel.distributeWeightsEqually() },
                    onSpread: { viewModel.fillRemainingEvenly() },
                    onReset: { viewModel.resetAllWeights() }
                )

                if viewModel.config.assetAllocations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie.fill").font(.system(size: 40)).foregroundColor(
                            .blue)
                        Text("Quick Start").font(.headline).foregroundColor(.textPrimary)
                        Text("Create a ready-to-use asset portfolio for testing").font(.subheadline)
                            .foregroundColor(.textSecondary).multilineTextAlignment(.center)
                        Button("Create Demo Portfolio") { createDemoPortfolio() }.buttonStyle(
                            PrimaryButtonStyle()
                        ).frame(width: 200)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.config.assetAllocations) { allocation in
                            AllocationRow(
                                allocation: allocation,
                                onChange: { newWeight in
                                    viewModel.updateAssetWeight(
                                        allocation.assetCode, weight: newWeight)
                                },
                                onRemove: { viewModel.removeAsset(allocation.assetCode) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }

    fileprivate var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: { viewModel.handlePrimaryAction() }) {
                HStack(spacing: 10) {
                    if viewModel.simulationState == .running {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else if let icon = viewModel.primaryButtonIcon {
                        Image(systemName: icon)
                    }
                    Text(viewModel.primaryButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            viewModel.simulationState == .running
                                || viewModel.isPrimaryButtonEnabled
                                ? Color.accentColor : Color.gray.opacity(0.4))
                )
                .foregroundColor(.white)
            }
            .disabled(!viewModel.isPrimaryButtonEnabled)

            if let loadingMessage = viewModel.priceLoadingMessage, !loadingMessage.isEmpty {
                Text(loadingMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            InlineSimulationResultsView(
                result: viewModel.result,
                transactions: viewModel.transactions
            )

            if !viewModel.config.assetAllocations.isEmpty {
                HStack(spacing: 12) {
                    Button("⚡ Demo Test (Defaults)") { runQuickTest() }.buttonStyle(
                        SecondaryButtonStyle()
                    ).frame(maxWidth: .infinity)
                    Button("🔄 Reset") { viewModel.resetSimulation() }.buttonStyle(
                        SecondaryButtonStyle()
                    ).frame(maxWidth: .infinity)
                }
            }

            if !viewModel.config.isValidWeightDistribution
                && !viewModel.config.assetAllocations.isEmpty
            {
                Text("⚠️ Asset allocation must be 100%").font(.caption).foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
}
// MARK: - Senaryolar Ana Sayfası

// MARK: - Previews
struct DCAScenarioView_Previews: PreviewProvider {
    static var previews: some View {
        DCAScenarioView()
    }
}

// MARK: - Inline Components (to ensure target inclusion)
// MARK: - Day Picker Sheet (removed inline duplicate; use Components/DayPickerSheet)
// MARK: - AllocationSummaryCard (removed inline duplicate; use Components/AllocationSummaryCard)
// MARK: - AllocationButtonsBar (removed inline duplicate; use Components/AllocationButtonsBar)
// MARK: - AllocationRow (removed inline duplicate; use Components/AllocationRow)
// MARK: - TemplateSaveSheet (removed inline duplicate; use Components/TemplateSaveSheet)

private struct SimulationResultsSection: View {
    let result: SimulationResult?
    let transactions: [Transaction]
    let config: ScenarioConfig?

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 20) {
            if let result {
                resultOverview(result)
                if let config {
                    SimulationMetaView(config: config, transactionCount: transactions.count)
                }
                assetBreakdown(result)
            } else {
                EmptyResultsView()
            }

            if !transactions.isEmpty {
                ResultsDisclosure(transactions: transactions, result: result)
            }
        }
    }

    private func resultOverview(_ result: SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Simulation Results")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                ResultStatCard(
                    title: "Total Investment",
                    value: formatted(result.investedTotalTRY),
                    subtitle: "Initial + Monthly"
                )
                ResultStatCard(
                    title: "Portfolio Value",
                    value: formatted(result.currentValueTRY),
                    subtitle: "End Date"
                )
                ResultStatCard(
                    title: "Total Return",
                    value: formatted(result.profitTRY),
                    subtitle: profitSubtitle(result.profitPct),
                    accentColor: result.profitTRY > 0
                        ? .green : (result.profitTRY < 0 ? .red : .secondary)
                )
            }
            .frame(maxWidth: .infinity)

            SummaryCardsView(result: result)
            BreakdownTableView(breakdown: result.breakdown, style: .card)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
        )
    }

    private func assetBreakdown(_ result: SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Returns by Asset")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(result.breakdown.sorted { $0.symbol < $1.symbol }, id: \.symbol) { row in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("Total: \(row.totalUnits.rounded(scale: 4).description) units")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatted(row.currentValueTRY))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(String(format: "%+.2f%%", row.pnlPct.doubleValue))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(row.pnlTRY >= 0 ? .green : .red)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
        )
    }

    private func formatted(_ value: Decimal) -> String {
        Self.currencyFormatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func profitSubtitle(_ pct: Decimal) -> String {
        let value = String(format: "%+.2f%%", pct.doubleValue)
        return "ROI: \(value)"
    }
}

private struct ResultStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var accentColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(accentColor)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct SimulationMetaView: View {
    let config: ScenarioConfig
    let transactionCount: Int

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Simülasyon Detayları")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12
            ) {
                metaRow(
                    title: "Başlangıç", value: Self.dateFormatter.string(from: config.startDate))
                metaRow(title: "Bitiş", value: Self.dateFormatter.string(from: config.endDate))
                metaRow(title: "Yatırım Sıklığı", value: frequencyText)
                metaRow(title: "Yatırım Günleri", value: daysText)
                metaRow(title: "İşlem Sayısı", value: "\(transactionCount)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
        )
    }

    private func metaRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var frequencyText: String {
        "Ayda \(config.frequency) kez"
    }

    private var daysText: String {
        guard let days = config.customDaysOfMonth, !days.isEmpty else { return "—" }
        return days.sorted().map { "\($0)" }.joined(separator: ", ")
    }
}

private struct EmptyResultsView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Henüz bir simülasyon çalıştırılmadı")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct ResultsDisclosure: View {
    let transactions: [Transaction]
    let result: SimulationResult?

    @State private var isExpanded = true
    @State private var selectedRange: TimeRangeFilter = .all
    @State private var selectedCategory: AssetCategoryFilter = .all
    @State private var selectedSort: SortOption = .newest

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(spacing: 16) {
            header

            if isExpanded {
                filterBar
                if monthlyCards.isEmpty {
                    FilterEmptyStateView()
                        .transition(.opacity)
                } else {
                    VStack(spacing: 16) {
                        ForEach(monthlyCards) { card in
                            MonthlyTransactionCard(data: card)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Text("Son İşlemler")
                    .font(.headline)
                    .foregroundColor(.primary)
                if !transactions.isEmpty {
                    Text("(\(transactions.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(isExpanded ? "Kapat" : "Göster")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.accentColor)
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundColor(.accentColor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                filterGroup(
                    title: "Süre", options: TimeRangeFilter.allCases, selection: $selectedRange)
                filterGroup(
                    title: "Varlık", options: AssetCategoryFilter.allCases,
                    selection: $selectedCategory)
                filterGroup(title: "Sırala", options: SortOption.allCases, selection: $selectedSort)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 2)
    }

    private func filterGroup<Option: FilterOption>(
        title: String, options: [Option], selection: Binding<Option>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(options, id: \.id) { option in
                    FilterPill(title: option.title, isSelected: option == selection.wrappedValue)
                        .onTapGesture {
                            selection.wrappedValue = option
                        }
                }
            }
        }
    }

    private var monthlyCards: [MonthlyCardData] {
        guard !transactions.isEmpty else { return [] }

        let roiLookup: [AssetCode: Decimal] = {
            guard let breakdown = result?.breakdown else { return [:] }
            return breakdown.reduce(into: [AssetCode: Decimal]()) { dict, row in
                if let code = assetCode(for: row.symbol) {
                    dict[code] = row.pnlPct
                }
            }
        }()

        let referenceDate = transactions.map(\.date).max() ?? Date()
        let threshold = selectedRange.threshold(reference: referenceDate, calendar: calendar)

        let rangeFiltered = transactions.filter { transaction in
            guard let threshold else { return true }
            return transaction.date >= threshold
        }

        let grouped = Dictionary(grouping: rangeFiltered) { transaction -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.date))
                ?? transaction.date
        }

        var cards: [MonthlyCardData] = []

        for (monthStart, entries) in grouped {
            if let card = makeMonthlyCard(
                for: monthStart, transactions: entries, roiLookup: roiLookup)
            {
                cards.append(card)
            }
        }

        switch selectedSort {
        case .newest:
            return cards.sorted { $0.monthStart > $1.monthStart }
        case .oldest:
            return cards.sorted { $0.monthStart < $1.monthStart }
        case .highestROI:
            return cards.sorted { $0.roiPercentage > $1.roiPercentage }
        }
    }

    private func makeMonthlyCard(
        for monthStart: Date, transactions: [Transaction], roiLookup: [AssetCode: Decimal]
    ) -> MonthlyCardData? {
        var assetMap: [AssetCode: AssetAggregation] = [:]

        for transaction in transactions {
            for item in transaction.distribution {
                var aggregation =
                    assetMap[item.assetCode]
                    ?? AssetAggregation(assetType: item.assetCode.assetType)
                aggregation.amount += item.amountTRY
                aggregation.units += item.units
                if item.unitPriceTRY > 0 {
                    aggregation.lastUnitPrice = item.unitPriceTRY
                }
                assetMap[item.assetCode] = aggregation
            }
        }

        var assets: [MonthlyAsset] = []

        for (code, aggregation) in assetMap {
            guard selectedCategory.matches(assetType: aggregation.assetType) else { continue }
            let amount = aggregation.amount.rounded(scale: 2)
            guard amount > 0 else { continue }
            let totalUnits = aggregation.units
            let unitPrice: Decimal
            if totalUnits > 0 {
                unitPrice = (amount / totalUnits).rounded(scale: 4)
            } else {
                unitPrice = aggregation.lastUnitPrice.rounded(scale: 4)
            }
            let asset = MonthlyAsset(
                code: code,
                name: code.displayName,
                symbol: code.symbol,
                assetType: aggregation.assetType,
                percentage: 0,
                amount: amount,
                unitPrice: unitPrice,
                quantity: totalUnits.rounded(scale: 6)
            )
            assets.append(asset)
        }

        guard !assets.isEmpty else { return nil }

        assets.sort { $0.amount > $1.amount }

        let totalAmount = assets.reduce(Decimal.zero) { $0 + $1.amount }
        guard totalAmount > 0 else { return nil }

        var accumulatedPercentage: Decimal = 0
        let normalizedAssets: [MonthlyAsset] = assets.enumerated().map { index, asset in
            var item = asset
            if index == assets.count - 1 {
                let remaining = (Decimal(100) - accumulatedPercentage).rounded(scale: 1)
                item.percentage = remaining.doubleValue
            } else {
                let percent = ((asset.amount / totalAmount) * 100).rounded(scale: 1)
                item.percentage = percent.doubleValue
                accumulatedPercentage += percent
            }
            return item
        }

        let roiPercentage = calculateROI(
            for: normalizedAssets, totalAmount: totalAmount, roiLookup: roiLookup)

        let monthLabel = Self.monthLabelFormatter.string(from: monthStart)
        let transactionsCount = transactions.count

        return MonthlyCardData(
            monthStart: monthStart,
            monthLabel: monthLabel.capitalized,
            totalInvestment: totalAmount,
            transactionsCount: transactionsCount,
            roiPercentage: roiPercentage,
            assets: normalizedAssets
        )
    }

    private static let monthLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private func calculateROI(
        for assets: [MonthlyAsset], totalAmount: Decimal, roiLookup: [AssetCode: Decimal]
    ) -> Double {
        guard totalAmount > 0 else { return 0 }
        var weighted: Decimal = 0
        for asset in assets {
            let roi = roiLookup[asset.code] ?? 0
            let contribution = asset.amount * (roi / 100)
            weighted += contribution
        }
        let average = (weighted / totalAmount) * 100
        return average.rounded(scale: 2).doubleValue
    }

    private func assetCode(for symbol: String) -> AssetCode? {
        AssetCode.allCases.first(where: { code in
            code.symbol.caseInsensitiveCompare(symbol) == .orderedSame
                || code.rawValue.caseInsensitiveCompare(symbol) == .orderedSame
        })
    }

    private struct MonthlyCardData: Identifiable {
        let id = UUID()
        let monthStart: Date
        let monthLabel: String
        let totalInvestment: Decimal
        let transactionsCount: Int
        let roiPercentage: Double
        let assets: [MonthlyAsset]
    }

    private struct MonthlyAsset: Identifiable {
        let id = UUID()
        let code: AssetCode
        let name: String
        let symbol: String
        let assetType: AssetType
        var percentage: Double
        let amount: Decimal
        let unitPrice: Decimal
        let quantity: Decimal
    }

    private struct AssetAggregation {
        var amount: Decimal = 0
        var units: Decimal = 0
        var lastUnitPrice: Decimal = 0
        let assetType: AssetType

        init(
            amount: Decimal = 0, units: Decimal = 0, lastUnitPrice: Decimal = 0,
            assetType: AssetType
        ) {
            self.amount = amount
            self.units = units
            self.lastUnitPrice = lastUnitPrice
            self.assetType = assetType
        }
    }

    private struct MonthlyTransactionCard: View {
        let data: MonthlyCardData

        private static let currencyFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "TRY"
            formatter.locale = Locale(identifier: "en_US")
            return formatter
        }()

        private static let quantityFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 6
            return formatter
        }()

        private static let priceFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "TRY"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.locale = Locale(identifier: "en_US")
            return formatter
        }()

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(data.monthLabel)
                            .font(.headline)
                        Text("\(data.transactionsCount) işlem")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Toplam Yatırım")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(
                            Self.currencyFormatter.string(
                                from: data.totalInvestment as NSDecimalNumber) ?? "₺0"
                        )
                        .font(.body.weight(.semibold))
                    }
                }

                HStack {
                    Text(roiText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(roiColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(roiColor.opacity(0.12))
                        )
                    Spacer()
                }

                VStack(spacing: 12) {
                    ForEach(data.assets) { asset in
                        MonthlyAssetRow(asset: asset)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
            )
        }

        private var roiText: String {
            if data.roiPercentage > 0 {
                return String(format: "+%.2f%%", data.roiPercentage)
            } else if data.roiPercentage < 0 {
                return String(format: "%.2f%%", data.roiPercentage)
            } else {
                return "0.00%"
            }
        }

        private var roiColor: Color {
            if data.roiPercentage > 0 { return .green }
            if data.roiPercentage < 0 { return .red }
            return .secondary
        }

        private struct MonthlyAssetRow: View {
            let asset: MonthlyAsset

            private static let currencyFormatter: NumberFormatter = {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = "TRY"
                formatter.locale = Locale(identifier: "en_US")
                return formatter
            }()

            private static let quantityFormatter: NumberFormatter = {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 6
                return formatter
            }()

            private static let priceFormatter: NumberFormatter = {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = "TRY"
                formatter.locale = Locale(identifier: "en_US")
                formatter.minimumFractionDigits = 2
                formatter.maximumFractionDigits = 2
                return formatter
            }()

            var body: some View {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: asset.code.fallbackIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.subheadline.weight(.semibold))
                        Text(asset.symbol)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(
                            Self.currencyFormatter.string(from: asset.amount as NSDecimalNumber)
                                ?? "₺0"
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(String(format: "%.1f%%", asset.percentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(
                            "Fiyat: \(Self.priceFormatter.string(from: asset.unitPrice as NSDecimalNumber) ?? "₺0")"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        Text(
                            "Adet: \(Self.quantityFormatter.string(from: asset.quantity as NSDecimalNumber) ?? "0")"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            private var color: Color {
                switch asset.assetType {
                case .crypto: return .orange
                case .commodity: return .yellow
                case .forex: return .blue

                case .us_stock: return Color(hex: "#3B82F6")  // Blue
                case .us_etf: return Color(hex: "#10B981")  // Green
                }
            }
        }
    }

    private struct FilterEmptyStateView: View {
        var body: some View {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Filtre kriterlerine uygun işlem bulunamadı")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private struct FilterPill: View {
        let title: String
        let isSelected: Bool

        var body: some View {
            Text(title)
                .font(.footnote.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(0.15)
                                : Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
    }

    private protocol FilterOption: Equatable {
        var id: String { get }
        var title: String { get }
    }

    private enum TimeRangeFilter: String, CaseIterable, FilterOption {
        case m1 = "1M"
        case m3 = "3M"
        case m6 = "6M"
        case y1 = "1Y"
        case all = "Tümü"

        var id: String { rawValue }
        var title: String { rawValue }

        func threshold(reference: Date, calendar: Calendar) -> Date? {
            switch self {
            case .m1:
                return calendar.date(byAdding: .month, value: -1, to: reference)
            case .m3:
                return calendar.date(byAdding: .month, value: -3, to: reference)
            case .m6:
                return calendar.date(byAdding: .month, value: -6, to: reference)
            case .y1:
                return calendar.date(byAdding: .year, value: -1, to: reference)
            case .all:
                return nil
            }
        }
    }

    private enum AssetCategoryFilter: String, CaseIterable, FilterOption {
        case all = "All"
        case crypto = "Crypto"
        case metal = "Metal"
        case currency = "Forex"
        case usStock = "US Stocks"
        case usETF = "US ETFs"

        var id: String { rawValue }
        var title: String { rawValue }

        func matches(assetType: AssetType) -> Bool {
            switch self {
            case .all:
                return true
            case .crypto:
                return assetType == .crypto
            case .metal:
                return assetType == .commodity
            case .currency:
                return assetType == .forex
            case .usStock:
                return assetType == .us_stock
            case .usETF:
                return assetType == .us_etf
            }
        }
    }

    private enum SortOption: String, CaseIterable, FilterOption {
        case newest = "Newest"
        case oldest = "Oldest"
        case highestROI = "Highest ROI"

        var id: String { rawValue }
        var title: String { rawValue }
    }
}
