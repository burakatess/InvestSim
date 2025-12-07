import Charts
import Combine
import CoreData
import Foundation
import OSLog
import SwiftUI

// MARK: - Scenario Builder ViewModel
final class DCASimulationVM: ObservableObject {
    enum BuilderStep: Int, CaseIterable {
        case dateAndPeriod = 0
        case investmentAmount = 1
        case portfolioAllocation = 2

        var title: String {
            switch self {
            case .dateAndPeriod: return "Date & Period"
            case .investmentAmount: return "Investment Amount"
            case .portfolioAllocation: return "Portfolio Allocation"
            }
        }
    }

    enum SimulationState: Equatable {
        case idle, ready, running, completed
    }

    // MARK: - Published Properties
    @Published var currentStep: BuilderStep = .dateAndPeriod
    @Published var scenarioName: String = ""
    @Published var startDate: Date =
        Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @Published var endDate: Date = Date()
    @Published var frequencyPerMonth: Int = 1
    @Published var investmentDays: [Int] = [10]
    @Published var investmentAmount: String = ""
    @Published var currency: String = "USD"
    @Published var annualIncrease: String = ""
    @Published var allocations: [AssetAllocation] = []

    @Published var isRunning = false
    @Published var result: SimulationResult? = nil
    @Published var transactions: [ScenarioTransaction] = []
    @Published var errorMessage: String? = nil
    @Published var simulationState: SimulationState = .idle

    private let logger = Logger(subsystem: "InvestSimulator", category: "DCASimulation")
    private var scenariosRepository: ScenariosRepository?
    private var priceManager: UnifiedPriceManager?

    // MARK: - Helper Struct
    struct AssetAllocation: Identifiable {
        let id = UUID()
        var assetCode: AssetCode?
        var percentage: String = ""

        var percentageValue: Decimal {
            Decimal(string: percentage.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
    }

    // MARK: - Computed
    var stepTitles: [String] {
        BuilderStep.allCases.map { $0.title }
    }

    var canProceedToNextStep: Bool {
        switch currentStep {
        case .dateAndPeriod:
            return startDate < endDate
        case .investmentAmount:
            guard
                let amount = Decimal(
                    string: investmentAmount.replacingOccurrences(of: ",", with: ".")),
                amount > 0
            else { return false }
            return true
        case .portfolioAllocation:
            return totalAllocationPercent == 100 && allocations.allSatisfy { $0.assetCode != nil }
        }
    }

    var totalAllocationPercent: Decimal {
        allocations.reduce(0) { $0 + $1.percentageValue }
    }

    var isAllocationValid: Bool {
        totalAllocationPercent == 100
    }

    // MARK: - Init
    init() {
        updateInvestmentDaysForFrequency()
    }

    // MARK: - Actions
    func configure(repository: ScenariosRepository?, priceManager: UnifiedPriceManager?) {
        self.scenariosRepository = repository
        self.priceManager = priceManager
    }

    func nextStep() {
        guard canProceedToNextStep else { return }
        if let next = BuilderStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentStep = next
            }
        }
    }

    func previousStep() {
        if let prev = BuilderStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentStep = prev
            }
        }
    }

    func updateFrequency(_ freq: Int) {
        frequencyPerMonth = freq
        updateInvestmentDaysForFrequency()
    }

    private func updateInvestmentDaysForFrequency() {
        let defaultDays = [10, 20, 28]
        investmentDays = Array(defaultDays.prefix(frequencyPerMonth))
    }

    func addAllocation() {
        allocations.append(AssetAllocation())
    }

    func addMultipleAllocations(assets: [AssetCode]) {
        for asset in assets {
            // Skip if already exists
            guard !allocations.contains(where: { $0.assetCode == asset }) else { continue }
            var allocation = AssetAllocation()
            allocation.assetCode = asset
            allocations.append(allocation)
        }
    }

    func removeAllocation(at index: Int) {
        guard allocations.indices.contains(index) else { return }
        allocations.remove(at: index)
    }

    func updateAllocationAsset(at index: Int, to asset: AssetCode) {
        guard allocations.indices.contains(index) else { return }
        allocations[index].assetCode = asset
    }

    func updateAllocationPercentage(at index: Int, to value: String) {
        guard allocations.indices.contains(index) else { return }
        allocations[index].percentage = value
    }

    func runSimulation() {
        guard canProceedToNextStep else {
            errorMessage = "Please fill in all fields"
            return
        }

        isRunning = true
        simulationState = .running

        Task {
            do {
                let result = try await Self.generateTransactionsWithRealPrices(
                    startDate: startDate,
                    endDate: endDate,
                    frequencyPerMonth: frequencyPerMonth,
                    investmentDays: investmentDays,
                    amount: Decimal(
                        string: investmentAmount.replacingOccurrences(of: ",", with: ".")) ?? 1000,
                    allocations: allocations
                )

                await MainActor.run {
                    self.transactions = result
                    self.simulationState = .completed
                    self.isRunning = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch prices: \(error.localizedDescription)"
                    self.simulationState = .idle
                    self.isRunning = false
                }
            }
        }
    }

    static func generateTransactionsWithRealPrices(
        startDate: Date,
        endDate: Date,
        frequencyPerMonth: Int,
        investmentDays: [Int],
        amount: Decimal,
        allocations: [AssetAllocation]
    ) async throws -> [ScenarioTransaction] {
        var transactions: [ScenarioTransaction] = []
        var cumulativeQuantities: [String: Decimal] = [:]
        let calendar = Calendar.current

        // Get all asset codes
        let assetCodes = allocations.compactMap { $0.assetCode?.rawValue }
        guard !assetCodes.isEmpty else { return [] }

        // Fetch all historical prices from Supabase
        let priceService = SupabaseHistoricalPriceService.shared
        let allPrices = try await priceService.fetchPrices(
            assetCodes: assetCodes,
            startDate: startDate,
            endDate: endDate
        )

        var currentDate = startDate

        while currentDate <= endDate {
            let month = calendar.component(.month, from: currentDate)
            let year = calendar.component(.year, from: currentDate)

            for dayOfMonth in investmentDays.prefix(frequencyPerMonth) {
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = min(dayOfMonth, 28)

                guard let investmentDate = calendar.date(from: components),
                    investmentDate >= startDate && investmentDate <= endDate
                else { continue }

                for allocation in allocations {
                    guard let asset = allocation.assetCode else { continue }

                    let allocatedAmount = amount * allocation.percentageValue / 100

                    // Get real price from cached prices
                    let priceMap = allPrices[asset.rawValue] ?? [:]
                    let price =
                        priceService.getClosestPrice(
                            assetCode: asset.rawValue,
                            targetDate: investmentDate,
                            priceCache: priceMap
                        ) ?? Decimal(1000)  // Fallback if no price found

                    let quantity = price > 0 ? allocatedAmount / price : 0

                    let cumulative = (cumulativeQuantities[asset.rawValue] ?? 0) + quantity
                    cumulativeQuantities[asset.rawValue] = cumulative

                    transactions.append(
                        ScenarioTransaction(
                            id: UUID(),
                            date: investmentDate,
                            asset: asset.rawValue,
                            priceUSD: price,
                            allocatedMoneyUSD: allocatedAmount,
                            quantity: quantity,
                            cumulativeQuantity: cumulative
                        ))
                }
            }

            currentDate =
                calendar.date(byAdding: .month, value: 1, to: currentDate)
                ?? endDate.addingTimeInterval(1)
        }

        return transactions.sorted { $0.date < $1.date }
    }
}

// MARK: - Scenario Transaction Model
struct ScenarioTransaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let asset: String
    let priceUSD: Decimal
    let allocatedMoneyUSD: Decimal
    let quantity: Decimal
    let cumulativeQuantity: Decimal

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - DCA Scenario View (3-Step Builder)
struct DCAScenarioView: View {
    @Environment(\._appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DCASimulationVM()
    @State private var isAppearing = false
    @State private var showBulkAssetPicker = false
    @State private var showResult = false

    // Excluded assets for pickers (already selected)
    private var excludedAssets: [AssetCode] {
        viewModel.allocations.compactMap { $0.assetCode }
    }

    var body: some View {
        ZStack {
            ScenarioBackgroundView()

            VStack(spacing: 0) {
                // Stepper Navigation
                ScenarioStepperNav(
                    currentStep: viewModel.currentStep.rawValue,
                    totalSteps: 3,
                    titles: viewModel.stepTitles
                )
                .padding(.top, 8)

                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        switch viewModel.currentStep {
                        case .dateAndPeriod:
                            step1DateAndPeriod
                        case .investmentAmount:
                            step2InvestmentAmount
                        case .portfolioAllocation:
                            step3PortfolioAllocation
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 20)
            }

            // Bottom Buttons
            VStack {
                Spacer()
                bottomButtons
            }
        }
        .navigationTitle("New Scenario")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(ScenarioDesign.textSecondary)
            }
        }
        .onAppear {
            viewModel.configure(
                repository: container.scenariosRepository,
                priceManager: container.priceManager
            )
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showBulkAssetPicker) {
            BulkAssetPickerSheet(
                onSelectMultiple: { assets in
                    viewModel.addMultipleAllocations(assets: assets)
                    showBulkAssetPicker = false
                },
                excludedAssets: excludedAssets
            )
        }
        .onChange(of: viewModel.simulationState) { oldState, newState in
            if newState == .completed {
                showResult = true
            }
        }
        .fullScreenCover(isPresented: $showResult) {
            NavigationStack {
                SimulationResultView(
                    scenarioName: viewModel.scenarioName.isEmpty
                        ? "DCA Scenario" : viewModel.scenarioName,
                    transactions: viewModel.transactions,
                    allocations: viewModel.allocations,
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate,
                    investmentAmount: Decimal(
                        string: viewModel.investmentAmount.replacingOccurrences(of: ",", with: "."))
                        ?? 1000
                )
            }
        }
    }

    // MARK: - Step 1: Date & Period
    private var step1DateAndPeriod: some View {
        VStack(spacing: 20) {
            ScenarioGlassCard(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Scenario Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ScenarioDesign.textSecondary)

                    TextField(
                        "", text: $viewModel.scenarioName,
                        prompt: Text("e.g. BTC DCA 2024").foregroundColor(
                            ScenarioDesign.textPlaceholder)
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ScenarioDesign.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
            }

            ScenarioGlassCard(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Date Range")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ScenarioDesign.textMuted)

                            DatePicker(
                                "", selection: $viewModel.startDate, displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(ScenarioDesign.accentCyan)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("End")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ScenarioDesign.textMuted)

                            DatePicker(
                                "", selection: $viewModel.endDate, displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(ScenarioDesign.accentCyan)
                        }
                    }
                }
            }

            ScenarioGlassCard(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Investment Frequency")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    ScenarioFrequencySelector(
                        selectedFrequency: Binding(
                            get: { viewModel.frequencyPerMonth },
                            set: { viewModel.updateFrequency($0) }
                        ))
                }
            }

            ScenarioGlassCard(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Investment Days (1-28)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    ForEach(0..<viewModel.frequencyPerMonth, id: \.self) { index in
                        ScenarioDayPicker(
                            label: "Day \(index + 1)",
                            day: Binding(
                                get: {
                                    viewModel.investmentDays.indices.contains(index)
                                        ? viewModel.investmentDays[index] : 1
                                },
                                set: { newValue in
                                    if viewModel.investmentDays.indices.contains(index) {
                                        viewModel.investmentDays[index] = newValue
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Investment Amount
    private var step2InvestmentAmount: some View {
        VStack(spacing: 20) {
            ScenarioGlassCard(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Monthly Investment Amount")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    HStack(spacing: 12) {
                        Text("$")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ScenarioDesign.accentCyan)

                        TextField(
                            "", text: $viewModel.investmentAmount,
                            prompt: Text("1000").foregroundColor(ScenarioDesign.textPlaceholder)
                        )
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)
                        .keyboardType(.decimalPad)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                    Text("This amount will be distributed to assets on each investment day")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                }
            }

            ScenarioGlassCard(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Currency")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    HStack {
                        Text("🇺🇸 USD")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ScenarioDesign.textPrimary)

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ScenarioDesign.accentCyan)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ScenarioDesign.accentCyan.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(ScenarioDesign.accentCyan.opacity(0.3), lineWidth: 1)
                            )
                    )

                    Text("Other currencies coming soon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                }
            }

            ScenarioGlassCard(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Annual Increase (Optional)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ScenarioDesign.textPrimary)

                        Spacer()

                        Text("Optional")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ScenarioDesign.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }

                    HStack(spacing: 12) {
                        TextField(
                            "", text: $viewModel.annualIncrease,
                            prompt: Text("0").foregroundColor(ScenarioDesign.textPlaceholder)
                        )
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ScenarioDesign.textPrimary)
                        .keyboardType(.decimalPad)

                        Text("%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ScenarioDesign.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Step 3: Portfolio Allocation
    private var step3PortfolioAllocation: some View {
        VStack(spacing: 20) {
            ScenarioGlassCard(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Portfolio Allocation")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ScenarioDesign.textPrimary)

                        Spacer()

                        Text(
                            "Total: %\(NSDecimalNumber(decimal: viewModel.totalAllocationPercent).intValue)"
                        )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(
                            viewModel.isAllocationValid
                                ? ScenarioDesign.positive : ScenarioDesign.warning)
                    }

                    if !viewModel.isAllocationValid {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                            Text("Total must be 100%")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(ScenarioDesign.warning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(ScenarioDesign.warning.opacity(0.12))
                        )
                    }
                }
            }

            // Allocation Rows
            ForEach(Array(viewModel.allocations.enumerated()), id: \.element.id) {
                index, allocation in
                AllocationInputRow(
                    allocation: allocation,
                    onAssetChange: { asset in
                        viewModel.updateAllocationAsset(at: index, to: asset)
                    },
                    onPercentageChange: { value in
                        viewModel.updateAllocationPercentage(at: index, to: value)
                    },
                    onDelete: {
                        viewModel.removeAllocation(at: index)
                    },
                    excludedAssets: excludedAssets.filter { $0 != allocation.assetCode }
                )
            }

            // Add Asset Button
            Button {
                viewModel.addAllocation()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Asset")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(ScenarioDesign.accentCyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ScenarioDesign.accentCyan.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ScenarioDesign.accentCyan.opacity(0.25), lineWidth: 1.5)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                        )
                )
            }
            .buttonStyle(.plain)

            // Bulk Add Button
            Button {
                showBulkAssetPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 16))
                    Text("Bulk Add Assets")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(ScenarioDesign.accentPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ScenarioDesign.accentPurple.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ScenarioDesign.accentPurple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 14) {
            if viewModel.currentStep != .dateAndPeriod {
                Button {
                    viewModel.previousStep()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(ScenarioDesign.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            if viewModel.currentStep == .portfolioAllocation {
                Button {
                    viewModel.runSimulation()
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Run Simulation")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                viewModel.canProceedToNextStep
                                    ? ScenarioDesign.accentGradient
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                        startPoint: .leading, endPoint: .trailing)
                            )
                            .shadow(
                                color: viewModel.canProceedToNextStep
                                    ? ScenarioDesign.accentPurple.opacity(0.4) : .clear, radius: 12,
                                x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canProceedToNextStep || viewModel.isRunning)
            } else {
                Button {
                    viewModel.nextStep()
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                viewModel.canProceedToNextStep
                                    ? ScenarioDesign.accentGradient
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                        startPoint: .leading, endPoint: .trailing)
                            )
                            .shadow(
                                color: viewModel.canProceedToNextStep
                                    ? ScenarioDesign.accentPurple.opacity(0.4) : .clear, radius: 12,
                                x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canProceedToNextStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.9))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Allocation Input Row
private struct AllocationInputRow: View {
    let allocation: DCASimulationVM.AssetAllocation
    let onAssetChange: (AssetCode) -> Void
    let onPercentageChange: (String) -> Void
    let onDelete: () -> Void
    let excludedAssets: [AssetCode]

    @State private var showAssetPicker = false
    @State private var percentageText: String = ""

    var body: some View {
        HStack(spacing: 14) {
            // Asset Selector
            Button {
                showAssetPicker = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: ScenarioDesign.cryptoGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        if let asset = allocation.assetCode {
                            Text(String(asset.symbol.prefix(2)).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Text(allocation.assetCode?.symbol ?? "Varlık Seç")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(
                            allocation.assetCode != nil
                                ? ScenarioDesign.textPrimary : ScenarioDesign.textMuted)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ScenarioDesign.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Percentage Input
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: Binding(
                        get: { allocation.percentage },
                        set: { onPercentageChange($0) }
                    ), prompt: Text("0").foregroundColor(ScenarioDesign.textPlaceholder)
                )
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ScenarioDesign.textPrimary)
                .keyboardType(.decimalPad)
                .frame(width: 50)
                .multilineTextAlignment(.trailing)

                Text("%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ScenarioDesign.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ScenarioDesign.negative.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerSheet(
                onSelect: { asset in
                    onAssetChange(asset)
                    showAssetPicker = false
                },
                excludedAssets: excludedAssets
            )
        }
    }
}

// MARK: - Asset Picker Sheet (Single Select - from Database)
private struct AssetPickerSheet: View {
    let onSelect: (AssetCode) -> Void
    let excludedAssets: [AssetCode]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    // Get assets from database via AssetCatalog
    private var allAssets: [AssetMetadata] {
        AssetCatalog.shared.assets.filter { $0.isActive }
    }

    private var filteredAssets: [AssetMetadata] {
        let available = allAssets.filter { !excludedAssets.contains($0.code) }
        if searchText.isEmpty { return available }
        return available.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText)
                || $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.code.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group by category
    private var groupedAssets: [(String, [AssetMetadata])] {
        let grouped = Dictionary(grouping: filteredAssets) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScenarioBackgroundView()

                VStack(spacing: 16) {
                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ScenarioDesign.textMuted)
                        TextField(
                            "", text: $searchText,
                            prompt: Text("Search assets...").foregroundColor(
                                ScenarioDesign.textPlaceholder)
                        )
                        .foregroundColor(ScenarioDesign.textPrimary)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(ScenarioDesign.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Asset count
                    HStack {
                        Text("\(filteredAssets.count) varlık bulundu")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ScenarioDesign.textMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // List by category
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedAssets, id: \.0) { category, assets in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(categoryDisplayName(category))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(ScenarioDesign.textSecondary)
                                        .padding(.horizontal, 20)

                                    ForEach(assets, id: \.code) { asset in
                                        Button {
                                            onSelect(asset.code)
                                        } label: {
                                            AssetRowView(asset: asset)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Varlık Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(ScenarioDesign.textSecondary)
                }
            }
        }
    }

    private func categoryDisplayName(_ category: String) -> String {
        switch category.lowercased() {
        case "crypto": return "🪙 Crypto"
        case "stock": return "📈 Stocks"
        case "forex", "currency": return "💱 Forex"
        case "commodity": return "🥇 Commodities"
        default: return category.capitalized
        }
    }
}

// MARK: - Bulk Asset Picker Sheet (Multi Select)
private struct BulkAssetPickerSheet: View {
    let onSelectMultiple: ([AssetCode]) -> Void
    let excludedAssets: [AssetCode]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedAssets: Set<AssetCode> = []

    private var allAssets: [AssetMetadata] {
        AssetCatalog.shared.assets.filter { $0.isActive && !excludedAssets.contains($0.code) }
    }

    private var filteredAssets: [AssetMetadata] {
        if searchText.isEmpty { return allAssets }
        return allAssets.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText)
                || $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.code.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedAssets: [(String, [AssetMetadata])] {
        let grouped = Dictionary(grouping: filteredAssets) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScenarioBackgroundView()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ScenarioDesign.textMuted)
                        TextField(
                            "", text: $searchText,
                            prompt: Text("Search assets...").foregroundColor(
                                ScenarioDesign.textPlaceholder)
                        )
                        .foregroundColor(ScenarioDesign.textPrimary)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(ScenarioDesign.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(20)

                    // Selection info
                    HStack {
                        Text("\(selectedAssets.count) varlık seçildi")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(
                                selectedAssets.isEmpty
                                    ? ScenarioDesign.textMuted : ScenarioDesign.accentCyan)

                        Spacer()

                        if !selectedAssets.isEmpty {
                            Button("Clear") {
                                selectedAssets.removeAll()
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ScenarioDesign.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Scrollable list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedAssets, id: \.0) { category, assets in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(categoryDisplayName(category))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(ScenarioDesign.textSecondary)

                                        Spacer()

                                        Button {
                                            let codes = Set(assets.map(\.code))
                                            if codes.isSubset(of: selectedAssets) {
                                                selectedAssets.subtract(codes)
                                            } else {
                                                selectedAssets.formUnion(codes)
                                            }
                                        } label: {
                                            Text(
                                                Set(assets.map(\.code)).isSubset(of: selectedAssets)
                                                    ? "Tümünü Kaldır" : "Tümünü Seç"
                                            )
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(ScenarioDesign.accentCyan)
                                        }
                                    }
                                    .padding(.horizontal, 20)

                                    ForEach(assets, id: \.code) { asset in
                                        Button {
                                            if selectedAssets.contains(asset.code) {
                                                selectedAssets.remove(asset.code)
                                            } else {
                                                selectedAssets.insert(asset.code)
                                            }
                                        } label: {
                                            HStack(spacing: 14) {
                                                // Checkbox
                                                ZStack {
                                                    RoundedRectangle(
                                                        cornerRadius: 6, style: .continuous
                                                    )
                                                    .fill(
                                                        selectedAssets.contains(asset.code)
                                                            ? ScenarioDesign.accentGradient
                                                            : LinearGradient(
                                                                colors: [Color.white.opacity(0.1)],
                                                                startPoint: .top, endPoint: .bottom)
                                                    )
                                                    .frame(width: 24, height: 24)

                                                    if selectedAssets.contains(asset.code) {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(.white)
                                                    }
                                                }

                                                // Asset icon
                                                ZStack {
                                                    Circle()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: gradientForCategory(
                                                                    asset.category),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing)
                                                        )
                                                        .frame(width: 36, height: 36)

                                                    Text(
                                                        String(asset.symbol.prefix(2)).uppercased()
                                                    )
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white)
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(asset.symbol)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(ScenarioDesign.textPrimary)
                                                    Text(asset.displayName)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(
                                                            ScenarioDesign.textSecondary
                                                        )
                                                        .lineLimit(1)
                                                }

                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(
                                                    cornerRadius: 14, style: .continuous
                                                )
                                                .fill(
                                                    selectedAssets.contains(asset.code)
                                                        ? ScenarioDesign.accentCyan.opacity(0.08)
                                                        : Color.white.opacity(0.04))
                                            )
                                            .padding(.horizontal, 20)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }

                    // Bottom action button
                    VStack(spacing: 0) {
                        Divider().background(Color.white.opacity(0.1))

                        ScenarioGradientButton(
                            title: selectedAssets.isEmpty
                                ? "Select Assets" : "Add \(selectedAssets.count) Asset(s)",
                            icon: "plus.circle.fill"
                        ) {
                            onSelectMultiple(Array(selectedAssets))
                        }
                        .disabled(selectedAssets.isEmpty)
                        .opacity(selectedAssets.isEmpty ? 0.5 : 1)
                        .padding(20)
                    }
                    .background(.ultraThinMaterial.opacity(0.3))
                }
            }
            .navigationTitle("Bulk Add Assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(ScenarioDesign.textSecondary)
                }
            }
        }
    }

    private func categoryDisplayName(_ category: String) -> String {
        switch category.lowercased() {
        case "crypto": return "🪙 Crypto"
        case "stock": return "📈 Stocks"
        case "forex", "currency": return "💱 Forex"
        case "commodity": return "🥇 Commodities"
        default: return category.capitalized
        }
    }

    private func gradientForCategory(_ category: String) -> [Color] {
        switch category.lowercased() {
        case "crypto": return ScenarioDesign.cryptoGradient
        case "stock": return ScenarioDesign.stockGradient
        case "forex", "currency": return ScenarioDesign.forexGradient
        case "commodity": return ScenarioDesign.commodityGradient
        default: return ScenarioDesign.cryptoGradient
        }
    }
}

// MARK: - Asset Row View
private struct AssetRowView: View {
    let asset: AssetMetadata

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientForCategory(asset.category),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)

                Text(String(asset.symbol.prefix(2)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ScenarioDesign.textPrimary)
                Text(asset.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ScenarioDesign.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ScenarioDesign.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
    }

    private func gradientForCategory(_ category: String) -> [Color] {
        switch category.lowercased() {
        case "crypto": return ScenarioDesign.cryptoGradient
        case "stock": return ScenarioDesign.stockGradient
        case "forex", "currency": return ScenarioDesign.forexGradient
        case "commodity": return ScenarioDesign.commodityGradient
        default: return ScenarioDesign.cryptoGradient
        }
    }
}

// MARK: - Simulation Result View
struct SimulationResultView: View {
    let scenarioName: String
    let transactions: [ScenarioTransaction]
    let allocations: [DCASimulationVM.AssetAllocation]
    let startDate: Date
    let endDate: Date
    let investmentAmount: Decimal

    @Environment(\.dismiss) private var dismiss
    @State private var isAppearing = false
    @State private var expandedMonths: Set<String> = []
    @State private var mockMultiplier: Decimal = 1.0  // Stored once to avoid recalculation

    // Computed properties
    private var totalInvested: Decimal {
        transactions.reduce(0) { $0 + $1.allocatedMoneyUSD }
    }

    private var currentValue: Decimal {
        // Uses stored mockMultiplier to avoid recalculation on every view update
        return totalInvested * mockMultiplier
    }

    private var profitLoss: Decimal {
        currentValue - totalInvested
    }

    private var profitLossPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return NSDecimalNumber(decimal: profitLoss / totalInvested * 100).doubleValue
    }

    private var groupedByMonth: [(String, [ScenarioTransaction])] {
        let grouped = Dictionary(grouping: transactions) { transaction -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            formatter.locale = Locale(identifier: "tr_TR")
            return formatter.string(from: transaction.date)
        }
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = lhs.value.first?.date, let rhsDate = rhs.value.first?.date else {
                return false
            }
            return lhsDate < rhsDate
        }
    }

    var body: some View {
        ZStack {
            ScenarioBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Summary Cards
                    summaryCards
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)

                    // Transaction History
                    transactionHistory
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 30)
                }
                .padding(20)
                .padding(.bottom, 100)
            }

            // Bottom action buttons
            VStack {
                Spacer()
                actionButtons
            }
        }
        .navigationTitle(scenarioName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundColor(ScenarioDesign.textSecondary)
            }
        }
        .onAppear {
            // Initialize mock multiplier once (for demo purposes)
            if mockMultiplier == 1.0 {
                mockMultiplier = Decimal(Double.random(in: 0.8...1.5))
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
    }

    // MARK: - Summary Cards
    private var summaryCards: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Total Investment",
                    value: formatCurrency(totalInvested),
                    icon: "dollarsign.circle.fill",
                    color: ScenarioDesign.accentCyan
                )

                StatCard(
                    title: "Current Value",
                    value: formatCurrency(currentValue),
                    icon: "chart.line.uptrend.xyaxis",
                    color: profitLoss >= 0 ? ScenarioDesign.positive : ScenarioDesign.negative
                )
            }

            HStack(spacing: 12) {
                StatCard(
                    title: "Profit/Loss",
                    value: "\(profitLoss >= 0 ? "+" : "")\(formatCurrency(profitLoss))",
                    icon: profitLoss >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    color: profitLoss >= 0 ? ScenarioDesign.positive : ScenarioDesign.negative
                )

                StatCard(
                    title: "Return",
                    value: String(
                        format: "%@%.1f%%", profitLossPercent >= 0 ? "+" : "", profitLossPercent),
                    icon: "percent",
                    color: profitLossPercent >= 0
                        ? ScenarioDesign.positive : ScenarioDesign.negative
                )
            }

            // Period info
            ScenarioGlassCard(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Period")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ScenarioDesign.textMuted)
                        Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ScenarioDesign.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Transactions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ScenarioDesign.textMuted)
                        Text("\(transactions.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ScenarioDesign.accentCyan)
                    }
                }
            }
        }
    }

    // MARK: - Transaction History
    private var transactionHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ScenarioDesign.textPrimary)

            ForEach(groupedByMonth, id: \.0) { month, monthTransactions in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedMonths.contains(month) },
                        set: { newValue in
                            if newValue {
                                expandedMonths.insert(month)
                            } else {
                                expandedMonths.remove(month)
                            }
                        }
                    )
                ) {
                    VStack(spacing: 8) {
                        ForEach(monthTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text(month)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ScenarioDesign.textPrimary)

                        Spacer()

                        Text("\(monthTransactions.count) transactions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ScenarioDesign.textMuted)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Text("New Scenario")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ScenarioDesign.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)

            ScenarioGradientButton(title: "Save", icon: "square.and.arrow.down") {
                // TODO: Save scenario
                dismiss()
            }
        }
        .padding(20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.9))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Helpers
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ScenarioDesign.textPrimary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ScenarioDesign.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Transaction Row
private struct TransactionRow: View {
    let transaction: ScenarioTransaction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.asset)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ScenarioDesign.textPrimary)

                HStack(spacing: 4) {
                    Text(transaction.formattedDate)
                    Text("@")
                    Text("$\(formatPrice(transaction.priceUSD))")
                        .foregroundColor(ScenarioDesign.accentCyan)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ScenarioDesign.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(formatDecimal(transaction.allocatedMoneyUSD))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ScenarioDesign.textPrimary)
                Text("\(formatDecimal(transaction.quantity)) units")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ScenarioDesign.textMuted)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }

    private func formatPrice(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.00"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DCAScenarioView()
    }
    .preferredColorScheme(.dark)
}
