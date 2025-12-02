import Combine
import CoreData
import OSLog
import SwiftUI

// MARK: - Senaryolar Ana Sayfası
enum ScenariosColors {
    static let backgroundTop = Color(hex: "#050B1F")
    static let backgroundBottom = Color(hex: "#101530")
    static let cardTop = Color(hex: "#1F2446")
    static let cardBottom = Color(hex: "#151938")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let border = Color.white.opacity(0.12)
}

struct ScenariosHomeView: View {
    @Environment(\._appContainer) private var container
    @StateObject private var viewModel = ScenariosHomeViewModel()
    @State private var navigationPath: [ScenariosHomeNavigationTarget] = []
    @State private var animateCards = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                LinearGradient(
                    colors: [ScenariosColors.backgroundTop, ScenariosColors.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                            .padding(.top, 8)
                        actionCards
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Scenarios")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: ScenariosHomeNavigationTarget.self) { destination in
                switch destination {
                case .new:
                    DCAScenarioView()
                case .resume(let summary):
                    DCAScenarioView(viewModel: viewModel.makeSimulationViewModel(for: summary))
                }
            }
        }
        .onAppear {
            viewModel.configure(with: container)
            withAnimation(.easeInOut(duration: 0.35)) {
                animateCards = true
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strategy Center")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundColor(ScenariosColors.textPrimary)
            Text("Scenarios allow you to test different investment strategies.")
                .font(.callout)
                .foregroundColor(ScenariosColors.textSecondary)
        }
    }

    private var actionCards: some View {
        VStack(spacing: 16) {
            scenarioActionCard(
                title: "Resume Last Simulation",
                subtitle: viewModel.lastSimulationSubtitle,
                icon: "play.circle.fill",
                tint: Color(hex: "#7C83FF"),
                isDisabled: !viewModel.hasSimulations
            ) {
                if let summary = viewModel.lastSimulation {
                    navigationPath.append(.resume(summary))
                }
            }
            .cardAnimation(animateCards)

            scenarioActionCard(
                title: "Create New Simulation",
                subtitle: "Start by defining a strategy from scratch",
                icon: "plus.circle.fill",
                tint: Color(hex: "#20C997"),
                isDisabled: false
            ) {
                navigationPath.append(.new)
            }
            .cardAnimation(animateCards, delay: 0.05)

            previousSimulationsCard
                .cardAnimation(animateCards, delay: 0.1)
        }
    }

    private func scenarioActionCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(ScenariosColors.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(ScenariosColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ScenariosColors.textSecondary)
                    .opacity(isDisabled ? 0.3 : 1)
            }
            .padding(20)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            LinearGradient(
                colors: [ScenariosColors.cardTop, ScenariosColors.cardBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ScenariosColors.border, lineWidth: 1)
        )
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var previousSimulationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previous Simulation Records")
                        .font(.headline)
                        .foregroundColor(ScenariosColors.textPrimary)
                    Text("Manage your last 10 simulations here")
                        .font(.subheadline)
                        .foregroundColor(ScenariosColors.textSecondary)
                }
                Spacer()
            }

            if viewModel.recentSimulations.isEmpty {
                Text("No saved simulations yet.")
                    .font(.callout)
                    .foregroundColor(ScenariosColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.recentSimulations) { summary in
                        Button {
                            navigationPath.append(.resume(summary))
                        } label: {
                            ScenarioHistoryRow(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [ScenariosColors.cardTop, ScenariosColors.cardBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ScenariosColors.border, lineWidth: 1)
        )
    }
}

struct ScenarioHistoryRow: View {
    let summary: ScenariosHomeViewModel.SimulationSummary

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(0.12))  // Changed from primaryBlue to blue for standard Color
                    .frame(width: 42, height: 42)
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ScenariosColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(summary.formattedUpdatedAt, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(ScenariosColors.textSecondary)
                    if let assetCountText = summary.assetCountText {
                        Label(assetCountText, systemImage: "cube")
                            .font(.caption)
                            .foregroundColor(ScenariosColors.textSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(summary.formattedProfit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(summary.profitStyle)
                if let pct = summary.formattedProfitPct {
                    Text(pct)
                        .font(.caption)
                        .foregroundColor(summary.profitStyle.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [ScenariosColors.cardTop, ScenariosColors.cardBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ScenariosColors.border, lineWidth: 1)
        )
    }
}

final class ScenariosHomeViewModel: ObservableObject {
    struct SimulationSummary: Identifiable, Hashable {
        let id: UUID
        let name: String
        let updatedAt: Date
        let profit: Decimal?
        let profitPercentage: Decimal?
        let assetCount: Int
        let config: ScenarioConfig?
        let objectID: NSManagedObjectID

        var displayName: String {
            name.isEmpty ? "Untitled Scenario" : name
        }

        var formattedUpdatedAt: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "en_US")
            return formatter.localizedString(for: updatedAt, relativeTo: Date())
        }

        var formattedProfit: String {
            guard let profit else { return "—" }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.currencySymbol = "$"
            formatter.locale = Locale(identifier: "en_US")
            let value = formatter.string(from: profit as NSDecimalNumber) ?? "$0"
            return value
        }

        var formattedProfitPct: String? {
            guard let profitPercentage else { return nil }
            return String(format: "%+.2f%%", profitPercentage.doubleValue)
        }

        var profitStyle: Color {
            guard let profit else { return .secondary }
            if profit > 0 { return .green }
            if profit < 0 { return .red }
            return .secondary
        }

        var assetCountText: String? {
            guard assetCount > 0 else { return nil }
            return "\(assetCount) assets"
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: SimulationSummary, rhs: SimulationSummary) -> Bool {
            lhs.id == rhs.id
        }
    }

    private let logger = Logger(subsystem: "InvestSimulator", category: "ScenariosHome")
    @Published private(set) var recentSimulations: [SimulationSummary] = []
    private var container: AppContainer?
    private var cancellables: Set<AnyCancellable> = []

    var hasSimulations: Bool { !recentSimulations.isEmpty }
    var lastSimulation: SimulationSummary? { recentSimulations.first }
    var lastSimulationSubtitle: String {
        guard let summary = lastSimulation else { return "No simulations yet" }
        return "Last updated: \(summary.formattedUpdatedAt)"
    }

    func configure(with container: AppContainer) {
        if self.container == nil {
            self.container = container
        }
        if cancellables.isEmpty {
            NotificationCenter.default.publisher(for: .scenarioDidSave)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.loadRecentSimulations()
                }
                .store(in: &cancellables)
        }
        loadRecentSimulations()
    }

    func makeSimulationViewModel(for summary: SimulationSummary) -> DCASimulationVM {
        let viewModel = DCASimulationVM()
        if let config = summary.config {
            viewModel.applyConfiguration(config)
        }
        if let container {
            viewModel.configure(with: container)
        } else if let repository = container?.scenariosRepository {
            viewModel.attach(repository: repository)
        }
        return viewModel
    }

    func loadRecentSimulations() {
        guard let context = container?.coreDataStack.viewContext else { return }
        context.perform { [weak self] in
            guard let self else { return }
            let request: NSFetchRequest<Scenario> = Scenario.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false),
            ]
            request.fetchLimit = 10
            do {
                let scenarios = try context.fetch(request)
                let seeds: [ScenarioSummarySeed] = scenarios.map { scenario in
                    let name = scenario.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let updatedAt = scenario.updatedAt ?? scenario.createdAt ?? Date()
                    let snapshots = scenario.snapshots as? Set<ScenarioSnapshot>
                    let latestSnapshot = snapshots?
                        .max(by: {
                            ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
                        })
                    let profit = latestSnapshot?.profitLoss?.decimalValue
                    let profitPct = latestSnapshot?.profitLossPercentage?.decimalValue
                    return ScenarioSummarySeed(
                        id: scenario.id ?? UUID(),
                        name: name,
                        updatedAt: updatedAt,
                        profit: profit,
                        profitPercentage: profitPct,
                        paramsData: scenario.paramsJSON,
                        objectID: scenario.objectID
                    )
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let summaries = seeds.compactMap { self.makeSummary(from: $0) }
                    self.recentSimulations = summaries
                }
            } catch {
                self.logger.error(
                    "Could not fetch scenario records: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    @MainActor
    private func makeSummary(from seed: ScenarioSummarySeed) -> SimulationSummary? {
        let config = decodeScenarioConfig(from: seed.paramsData)
        let assetCount = config?.assetAllocations.count ?? 0
        let resolvedName = seed.name.isEmpty ? (config?.name ?? "") : seed.name
        return SimulationSummary(
            id: seed.id,
            name: resolvedName,
            updatedAt: seed.updatedAt,
            profit: seed.profit,
            profitPercentage: seed.profitPercentage,
            assetCount: assetCount,
            config: config,
            objectID: seed.objectID
        )
    }

    @MainActor
    private func decodeScenarioConfig(from data: Data?) -> ScenarioConfig? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(ScenarioConfig.self, from: data) {
            return decoded
        }
        if let snapshot = try? decoder.decode(ScenarioConfigSnapshot.self, from: data) {
            return snapshot.toScenarioConfig()
        }
        let fallbackDecoder = JSONDecoder()
        if let snapshot = try? fallbackDecoder.decode(ScenarioConfigSnapshot.self, from: data) {
            return snapshot.toScenarioConfig()
        }
        return try? fallbackDecoder.decode(ScenarioConfig.self, from: data)
    }
}

enum ScenariosHomeNavigationTarget: Hashable {
    case new
    case resume(ScenariosHomeViewModel.SimulationSummary)
}

private struct ScenarioSummarySeed {
    let id: UUID
    let name: String
    let updatedAt: Date
    let profit: Decimal?
    let profitPercentage: Decimal?
    let paramsData: Data?
    let objectID: NSManagedObjectID
}

extension View {
    fileprivate func cardAnimation(_ animate: Bool, delay: Double = 0) -> some View {
        self
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .animation(.easeInOut(duration: 0.35).delay(delay), value: animate)
    }
}
