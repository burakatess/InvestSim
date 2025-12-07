import Charts
import Combine
import CoreData
import OSLog
import SwiftUI

// MARK: - Scenario Card Data (for UI display)
struct ScenarioCardData: Identifiable, Hashable {
    let id: UUID
    let name: String
    let startDate: Date
    let endDate: Date
    let frequencyPerMonth: Int
    let totalInvestedUSD: Decimal
    let finalValueUSD: Decimal
    let roiPercent: Double
    let sparklineData: [Double]
    let createdAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScenarioCardData, rhs: ScenarioCardData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Navigation Target
enum ScenariosHomeNavigationTarget: Hashable {
    case builder
    case result(ScenarioCardData)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .builder:
            hasher.combine("builder")
        case .result(let data):
            hasher.combine("result")
            hasher.combine(data.id)
        }
    }

    static func == (lhs: ScenariosHomeNavigationTarget, rhs: ScenariosHomeNavigationTarget) -> Bool
    {
        switch (lhs, rhs) {
        case (.builder, .builder):
            return true
        case (.result(let lhsData), .result(let rhsData)):
            return lhsData.id == rhsData.id
        default:
            return false
        }
    }
}

// MARK: - Scenarios Home ViewModel
final class ScenariosHomeViewModel: ObservableObject {
    @Published var scenarios: [ScenarioCardData] = []
    @Published var isLoading = false
    @Published var showLimitAlert = false
    @Published var showDeleteConfirmation = false
    @Published var scenarioToDelete: ScenarioCardData?

    private var scenariosRepository: ScenariosRepository?
    private var hasLoaded = false
    private let logger = Logger(subsystem: "InvestSimulator", category: "ScenariosHome")

    static let maxScenarios = 10

    var canAddScenario: Bool {
        scenarios.count < Self.maxScenarios
    }

    var lastSimulationSubtitle: String {
        guard let last = scenarios.first else {
            return "No simulations yet"
        }
        return last.name
    }

    func configure(with container: AppContainer?) {
        self.scenariosRepository = container?.scenariosRepository
        loadScenarios()
    }

    func loadScenarios() {
        // Only load mock data once to preserve user deletions
        guard !hasLoaded else { return }

        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.scenarios = Self.mockScenarios
            self.isLoading = false
            self.hasLoaded = true
        }
    }

    func deleteScenario(_ scenario: ScenarioCardData) {
        scenarios.removeAll { $0.id == scenario.id }
    }

    func checkLimitAndProceed() -> Bool {
        if canAddScenario {
            return true
        } else {
            showLimitAlert = true
            return false
        }
    }

    static var mockScenarios: [ScenarioCardData] {
        [
            ScenarioCardData(
                id: UUID(),
                name: "BTC DCA 2023",
                startDate: Date().addingTimeInterval(-365 * 24 * 3600),
                endDate: Date(),
                frequencyPerMonth: 2,
                totalInvestedUSD: 24000,
                finalValueUSD: 32400,
                roiPercent: 35.0,
                sparklineData: [100, 105, 98, 112, 120, 115, 130, 128, 135],
                createdAt: Date()
            ),
            ScenarioCardData(
                id: UUID(),
                name: "Altın + Hisse Karışık",
                startDate: Date().addingTimeInterval(-180 * 24 * 3600),
                endDate: Date(),
                frequencyPerMonth: 1,
                totalInvestedUSD: 12000,
                finalValueUSD: 11400,
                roiPercent: -5.0,
                sparklineData: [100, 97, 95, 92, 94, 96, 95],
                createdAt: Date().addingTimeInterval(-86400)
            ),
        ]
    }
}

// MARK: - Scenarios Home View
struct ScenariosHomeView: View {
    @Environment(\._appContainer) private var container
    @StateObject private var viewModel = ScenariosHomeViewModel()
    @State private var navigationPath: [ScenariosHomeNavigationTarget] = []
    @State private var isAppearing = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ScenarioBackgroundView()

                VStack(spacing: 0) {
                    headerSection
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
                        .padding(.top, 16)

                    if viewModel.isLoading {
                        Spacer()
                        loadingView
                        Spacer()
                    } else if viewModel.scenarios.isEmpty {
                        Spacer()
                        emptyStateView
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            scenariosList
                                .opacity(isAppearing ? 1 : 0)
                                .offset(y: isAppearing ? 0 : 20)
                                .padding(.top, 24)
                                .padding(.bottom, 100)
                        }
                    }
                }

                floatingActionButton
            }
            .navigationDestination(for: ScenariosHomeNavigationTarget.self) { target in
                switch target {
                case .builder:
                    DCAScenarioView()
                case .result(let cardData):
                    ScenarioResultView(cardData: cardData)
                }
            }
        }
        .alert("Scenario Limit", isPresented: $viewModel.showLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "You can save up to 10 scenarios. Delete an existing scenario to add a new one."
            )
        }
        .alert("Delete Scenario", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let scenario = viewModel.scenarioToDelete {
                    viewModel.deleteScenario(scenario)
                }
            }
        } message: {
            Text("Are you sure you want to delete this scenario?")
        }
        .onAppear {
            viewModel.configure(with: container)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scenarios")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ScenarioDesign.textPrimary)

                Text("Test your investment strategies")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ScenarioDesign.textSecondary)
            }

            Spacer()

            Button {
                if viewModel.checkLimitAndProceed() {
                    navigationPath.append(.builder)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("New")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(ScenarioDesign.accentGradient)
                        .shadow(
                            color: ScenarioDesign.accentPurple.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ScenarioDesign.accentCyan))
                .scaleEffect(1.2)

            Text("Loading scenarios...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ScenarioDesign.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ScenarioGlassCard(spacing: 20) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(ScenarioDesign.accentPurple.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(ScenarioDesign.accentCyan)
                }

                VStack(spacing: 8) {
                    Text("No scenarios yet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    Text("Create your first investment scenario to test different strategies.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ScenarioDesign.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ScenarioGradientButton(title: "Create Scenario", icon: "plus") {
                    if viewModel.checkLimitAndProceed() {
                        navigationPath.append(.builder)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Scenarios List
    private var scenariosList: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Saved Scenarios")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ScenarioDesign.textPrimary)

                Spacer()

                Text("\(viewModel.scenarios.count)/10")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ScenarioDesign.textMuted)
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 14) {
                ForEach(viewModel.scenarios) { scenario in
                    ScenarioCard(
                        scenario: scenario,
                        onView: {
                            navigationPath.append(.result(scenario))
                        },
                        onEdit: {
                            navigationPath.append(.builder)
                        },
                        onDelete: {
                            viewModel.scenarioToDelete = scenario
                            viewModel.showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - FAB
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    if viewModel.checkLimitAndProceed() {
                        navigationPath.append(.builder)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(ScenarioDesign.accentGradient)
                            .frame(width: 60, height: 60)
                            .shadow(
                                color: ScenarioDesign.accentPurple.opacity(0.5), radius: 16, x: 0,
                                y: 8)

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Scenario Card
private struct ScenarioCard: View {
    let scenario: ScenarioCardData
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return
            "\(formatter.string(from: scenario.startDate)) - \(formatter.string(from: scenario.endDate))"
    }

    private var frequencyBadgeText: String {
        "\(scenario.frequencyPerMonth)x/month"
    }

    private var roiColor: Color {
        if scenario.roiPercent > 0 { return ScenarioDesign.positive }
        if scenario.roiPercent < 0 { return ScenarioDesign.negative }
        return ScenarioDesign.neutral
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scenario.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    Text(dateRangeText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ScenarioDesign.textSecondary)

                    Text(frequencyBadgeText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ScenarioDesign.accentCyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(ScenarioDesign.accentCyan.opacity(0.15))
                        )
                }

                Spacer()

                Chart {
                    ForEach(Array(scenario.sparklineData.enumerated()), id: \.offset) {
                        index, value in
                        LineMark(
                            x: .value("X", index),
                            y: .value("Y", value)
                        )
                        .foregroundStyle(roiColor)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 80, height: 40)
            }

            Divider()
                .background(Color.white.opacity(0.08))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invested")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                    Text(
                        "$\(NSDecimalNumber(decimal: scenario.totalInvestedUSD).intValue.formatted())"
                    )
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ScenarioDesign.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Final Value")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                    Text(
                        "$\(NSDecimalNumber(decimal: scenario.finalValueUSD).intValue.formatted())"
                    )
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ScenarioDesign.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ROI")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                    Text(String(format: "%+.1f%%", scenario.roiPercent))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(roiColor)
                }
            }

            Divider()
                .background(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                Button(action: onView) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .semibold))
                        Text("View")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(ScenarioDesign.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(ScenarioDesign.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ScenarioDesign.negative)
                        .frame(width: 44, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(ScenarioDesign.negative.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.30), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Preview
#Preview {
    ScenariosHomeView()
        .preferredColorScheme(.dark)
}
