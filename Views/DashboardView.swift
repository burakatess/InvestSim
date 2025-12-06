import Charts
import SwiftUI

// MARK: - Missing Types
struct PortfolioDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct AssetAllocationItem: Identifiable {
    let id = UUID()
    let asset: AssetCode
    let value: Double
    let percentage: Double
    let color: Color
}

// MARK: - Premium Portfolio Design System
private enum PortfolioDesign {
    static let bgStart = Color(hex: "#0B1120")
    static let bgMid1 = Color(hex: "#141A33")
    static let bgMid2 = Color(hex: "#1A1F3D")
    static let bgEnd = Color(hex: "#2A2F5C")

    static let accentPurple = Color(hex: "#7C4DFF")
    static let accentCyan = Color(hex: "#4CC9F0")

    static let positive = Color(hex: "#4EF47A")
    static let negative = Color(hex: "#FF5C5C")
    static let neutral = Color(hex: "#A0A0A0")

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.55)

    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: bgStart, location: 0.0),
            .init(color: bgMid1, location: 0.3),
            .init(color: bgMid2, location: 0.6),
            .init(color: bgEnd, location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accentPurple, accentCyan],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - SortOption Enum
enum SortOption: String, CaseIterable {
    case valueDesc = "value_high_to_low"
    case valueAsc = "value_low_to_high"
    case nameAsc = "name_a_to_z"
    case nameDesc = "name_z_to_a"
    case profitDesc = "profit_high_to_low"
    case profitAsc = "profit_low_to_high"

    var localizedTitle: String {
        switch self {
        case .valueDesc: return "Value (High → Low)"
        case .valueAsc: return "Value (Low → High)"
        case .nameAsc: return "Name (A → Z)"
        case .nameDesc: return "Name (Z → A)"
        case .profitDesc: return "Profit (High → Low)"
        case .profitAsc: return "Profit (Low → High)"
        }
    }
}

// MARK: - Premium Glass Card
private struct PremiumGlassCard<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 12)
        )
    }
}

// MARK: - Placeholder Sheet Views
struct SortOptionsView: View {
    @Binding var selectedOption: SortOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                PortfolioDesign.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 16) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            selectedOption = option
                            dismiss()
                        } label: {
                            HStack {
                                Text(option.localizedTitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(PortfolioDesign.accentCyan)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        selectedOption == option
                                            ? Color.white.opacity(0.1) : Color.white.opacity(0.05)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                selectedOption == option
                                                    ? PortfolioDesign.accentCyan
                                                    : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SellAssetSheet: View {
    @ObservedObject var viewModel: DashboardVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                PortfolioDesign.backgroundGradient.ignoresSafeArea()
                Text("Sell Asset - Coming Soon")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .navigationTitle("Sell Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FilterOptionsView: View {
    @Binding var selectedAssetType: AssetCode?
    @Binding var minValue: Double
    @Binding var maxValue: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                PortfolioDesign.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 20) {
                    Button {
                        selectedAssetType = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("All Assets")
                                .foregroundColor(.white)
                            Spacer()
                            if selectedAssetType == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(PortfolioDesign.accentCyan)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                    }

                    Text("Value Range: \(Int(minValue)) - \(Int(maxValue))")
                        .font(.caption)
                        .foregroundColor(PortfolioDesign.textSecondary)
                }
                .padding()
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailedTradeHistoryView: View {
    @ObservedObject var viewModel: DashboardVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                PortfolioDesign.backgroundGradient.ignoresSafeArea()

                if viewModel.recentTrades.isEmpty {
                    Text("No transactions yet")
                        .foregroundColor(PortfolioDesign.textSecondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.recentTrades) { trade in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(trade.asset.rawValue)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(trade.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(PortfolioDesign.textSecondary)
                                    }
                                    Spacer()
                                    Text(trade.type == .buy ? "BUY" : "SELL")
                                        .font(.caption.bold())
                                        .foregroundColor(
                                            trade.type == .buy
                                                ? PortfolioDesign.positive
                                                : PortfolioDesign.negative)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 14).fill(
                                        Color.white.opacity(0.05)))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                PortfolioDesign.backgroundGradient.ignoresSafeArea()
                Text("Export Options - Coming Soon")
                    .foregroundColor(.white)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AllocationDetailsView: View {
    let items: [AssetAllocationItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                PortfolioDesign.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            HStack {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 12, height: 12)
                                Text(item.asset.symbol)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(String(format: "%.1f%%", item.percentage))
                                        .font(.headline)
                                        .foregroundColor(PortfolioDesign.accentCyan)
                                    Text(String(format: "%.2f TL", item.value))
                                        .font(.caption)
                                        .foregroundColor(PortfolioDesign.textSecondary)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Asset Allocation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Portfolio Header Card
private struct PortfolioHeaderCardView: View {
    @ObservedObject var portfolioManager: PortfolioManager
    let totalValue: Double
    let dailyChange: Double
    let dailyChangePercentage: Double
    @Binding var isHidden: Bool
    @Binding var showingPortfolioMenu: Bool

    var body: some View {
        PremiumGlassCard(spacing: 20) {
            HStack {
                Button {
                    showingPortfolioMenu = true
                } label: {
                    HStack(spacing: 12) {
                        if let portfolio = portfolioManager.currentPortfolio {
                            ZStack {
                                Circle()
                                    .fill(PortfolioDesign.accentGradient)
                                    .frame(width: 44, height: 44)

                                Image(systemName: portfolio.color.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(portfolio.name)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(PortfolioDesign.textPrimary)

                                Text("\(portfolioManager.portfolios.count) portfolios")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(PortfolioDesign.textMuted)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PortfolioDesign.textMuted)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHidden.toggle()
                    }
                } label: {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PortfolioDesign.textMuted)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Total Portfolio Value")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PortfolioDesign.textSecondary)

                HStack(alignment: .bottom, spacing: 16) {
                    Text(isHidden ? "••••••••" : formatCurrency(totalValue))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(PortfolioDesign.accentGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Daily Change")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(PortfolioDesign.textMuted)

                        HStack(spacing: 6) {
                            Image(
                                systemName: dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .font(.system(size: 12, weight: .bold))

                            Text(isHidden ? "••••" : formatCurrency(abs(dailyChange)))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(
                            dailyChange >= 0 ? PortfolioDesign.positive : PortfolioDesign.negative
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    (dailyChange >= 0
                                        ? PortfolioDesign.positive : PortfolioDesign.negative)
                                        .opacity(0.15))
                        )

                        Text(isHidden ? "••%" : String(format: "%+.2f%%", dailyChangePercentage))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(
                                dailyChange >= 0
                                    ? PortfolioDesign.positive : PortfolioDesign.negative)
                    }
                }
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: value)) ?? "0.00") TL"
    }
}

// MARK: - Quick Action Button
private struct QuickActionButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: gradient[0].opacity(0.4), radius: 16, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Range Selector
private struct TimeRangeSelector: View {
    @Binding var selectedRange: DashboardView.ChartTimeRange

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardView.ChartTimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedRange = range
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(
                                selectedRange == range ? .white : PortfolioDesign.textSecondary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedRange == range {
                                        Capsule()
                                            .fill(PortfolioDesign.accentGradient)
                                            .shadow(
                                                color: PortfolioDesign.accentPurple.opacity(0.4),
                                                radius: 8, x: 0, y: 4)
                                    } else {
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                Capsule().stroke(
                                                    Color.white.opacity(0.12), lineWidth: 1))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Premium Asset Card
private struct PremiumAssetCard: View {
    let asset: UserAsset
    let totalPortfolioValue: Double
    let isHidden: Bool
    let assetColor: Color
    let assetIcon: String

    private var weight: Double {
        guard totalPortfolioValue > 0 else { return 0 }
        return (asset.currentValue / totalPortfolioValue) * 100
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [assetColor, assetColor.opacity(0.6)], startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: assetColor.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: assetIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.asset.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PortfolioDesign.textPrimary)

                Text(asset.asset.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PortfolioDesign.textSecondary)
                    .lineLimit(1)

                Text("\(String(format: "%.4f", asset.quantity)) units")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PortfolioDesign.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(isHidden ? "••••••" : formatCurrency(asset.currentValue))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PortfolioDesign.textPrimary)

                Text(String(format: "%.1f%%", weight))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(PortfolioDesign.accentCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(
                            PortfolioDesign.accentCyan.opacity(0.15)))

                Text(isHidden ? "••••" : "@ \(formatCurrencyShort(asset.currentPrice))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PortfolioDesign.textMuted)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: value)) ?? "0.00") TL"
    }

    private func formatCurrencyShort(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - Premium Segment Control
private struct PremiumSegmentControl: View {
    @Binding var selectedTab: DashboardView.DashboardTab
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(
                [DashboardView.DashboardTab.overview, DashboardView.DashboardTab.transactions],
                id: \.self
            ) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab == .overview ? "My Assets" : "Transactions")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(
                                selectedTab == tab
                                    ? PortfolioDesign.textPrimary : PortfolioDesign.textMuted)

                        ZStack {
                            Rectangle().fill(Color.clear).frame(height: 3)
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(PortfolioDesign.accentGradient)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "tabIndicator", in: animation)
                                    .shadow(
                                        color: PortfolioDesign.accentPurple.opacity(0.5), radius: 4,
                                        x: 0, y: 2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @StateObject private var portfolioManager = PortfolioManager()
    @StateObject private var viewModel: DashboardVM
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var settings = SettingsManager.shared

    // UI State
    @State private var showingAddAsset = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .valueDesc
    @State private var showingSortOptions = false
    @State private var showingSellAssetSheet = false
    @State private var selectedTab: DashboardTab = .overview
    @State private var isHidden = false
    @State private var showingFilterOptions = false
    @State private var selectedAssetType: AssetCode? = nil
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 1_000_000
    @State private var selectedTimeRange: ChartTimeRange = .month3
    @State private var showingDetailedHistory = false
    @State private var showingExportOptions = false
    @State private var showingRealtimePrices = false
    @State private var showingAssetAllocationDetails = false
    @State private var highlightedPortfolioPoint: PortfolioDataPoint?
    @State private var showingPortfolioMenu = false
    @State private var showingEditPortfolio = false
    @State private var selectedPortfolio: Portfolio?
    @State private var showingAddPortfolio = false
    @State private var isAppearing = false

    init(container: AppContainer) {
        let portfolioManager = PortfolioManager()
        self._portfolioManager = StateObject(wrappedValue: portfolioManager)
        self._viewModel = StateObject(
            wrappedValue: DashboardVM(container: container, portfolioManager: portfolioManager)
        )
    }

    enum ChartTimeRange: String, CaseIterable {
        case day1 = "1D"
        case week1 = "1W"
        case month1 = "1M"
        case month3 = "3M"
        case year1 = "1Y"
        case all = "ALL"

        var days: Int {
            switch self {
            case .day1: return 1
            case .week1: return 7
            case .month1: return 30
            case .month3: return 90
            case .year1: return 365
            case .all: return 1095
            }
        }
    }

    enum DashboardTab: String, CaseIterable {
        case overview, transactions, earn
    }

    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            PortfolioDesign.backgroundGradient
            RadialGradient(
                colors: [PortfolioDesign.accentPurple.opacity(0.12), .clear], center: .topTrailing,
                startRadius: 50, endRadius: 400)
            RadialGradient(
                colors: [PortfolioDesign.accentCyan.opacity(0.08), .clear], center: .bottomLeading,
                startRadius: 50, endRadius: 350)
        }
        .ignoresSafeArea()
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 14) {
            QuickActionButton(
                title: "Add Asset", icon: "plus",
                gradient: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")]
            ) {
                showingAddAsset = true
            }
            QuickActionButton(
                title: "Sell Asset", icon: "minus",
                gradient: [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
            ) {
                showingSellAssetSheet = true
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Performance Chart
    private var performanceChartSection: some View {
        let history = generatePortfolioHistory()

        return PremiumGlassCard(spacing: 18) {
            HStack {
                Text("Portfolio Performance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PortfolioDesign.textPrimary)
                Spacer()
            }

            TimeRangeSelector(selectedRange: $selectedTimeRange)

            if viewModel.userAssets.isEmpty || history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(PortfolioDesign.textMuted)
                    Text("No assets added yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(PortfolioDesign.textSecondary)
                }
                .frame(height: 130)
            } else {
                Chart {
                    ForEach(history) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(PortfolioDesign.accentGradient)
                            .interpolationMethod(.catmullRom)

                        AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        PortfolioDesign.accentPurple.opacity(0.20),
                                        PortfolioDesign.accentCyan.opacity(0.02),
                                    ], startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(selectedTimeRange.days / 5, 1)))
                    { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(
                            PortfolioDesign.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatCurrencyShort(v)).foregroundColor(
                                    PortfolioDesign.textMuted)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Asset Allocation
    private var allocationSection: some View {
        let data = generateAssetAllocationData()

        return PremiumGlassCard(spacing: 18) {
            HStack {
                Text("Asset Allocation")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PortfolioDesign.textPrimary)

                Spacer()

                Button {
                    if !data.isEmpty { showingAssetAllocationDetails = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Details")
                        Image(systemName: "chevron.right").font(
                            .system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PortfolioDesign.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.white.opacity(0.08)).overlay(
                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }

            if data.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie").font(.system(size: 48)).foregroundColor(
                        PortfolioDesign.textMuted)
                    Text("No assets added yet").font(.system(size: 16, weight: .medium))
                        .foregroundColor(PortfolioDesign.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                HStack(spacing: 16) {
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("Weight", item.value), innerRadius: .ratio(0.68),
                            outerRadius: .ratio(0.98), angularInset: 1
                        )
                        .cornerRadius(4)
                        .foregroundStyle(item.color)
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(data.sorted { $0.percentage > $1.percentage }.prefix(5)) { item in
                            HStack(spacing: 8) {
                                Circle().fill(item.color).frame(width: 10, height: 10)
                                Text(item.asset.symbol).font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PortfolioDesign.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f%%", item.percentage)).font(
                                    .system(size: 12, weight: .semibold)
                                ).foregroundColor(PortfolioDesign.accentCyan)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Assets List
    private var assetsListSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(PortfolioDesign.textMuted)
                    TextField(
                        "", text: $searchText,
                        prompt: Text("Search assets...").foregroundColor(PortfolioDesign.textMuted)
                    )
                    .foregroundColor(PortfolioDesign.textPrimary)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(
                                PortfolioDesign.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
                        Color.white.opacity(0.06)
                    ).overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(
                            Color.white.opacity(0.10), lineWidth: 1)))

                Button {
                    showingFilterOptions = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill").font(
                        .system(size: 20)
                    ).foregroundColor(PortfolioDesign.textPrimary).frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(
                                Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    showingSortOptions = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill").font(.system(size: 20))
                        .foregroundColor(PortfolioDesign.textPrimary).frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(
                                Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            if sortedAndFilteredAssets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray").font(.system(size: 48)).foregroundColor(
                        PortfolioDesign.textMuted)
                    Text(searchText.isEmpty ? "No assets added yet" : "No matching assets").font(
                        .system(size: 16, weight: .medium)
                    ).foregroundColor(PortfolioDesign.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(sortedAndFilteredAssets) { asset in
                        PremiumAssetCard(
                            asset: asset, totalPortfolioValue: viewModel.totalValue,
                            isHidden: isHidden, assetColor: assetColor(asset.asset),
                            assetIcon: assetIcon(asset.asset))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Transactions
    private var transactionsSection: some View {
        PremiumGlassCard(spacing: 16) {
            HStack {
                Text("Transaction History").font(.system(size: 18, weight: .bold)).foregroundColor(
                    PortfolioDesign.textPrimary)
                Spacer()
                Button("View All") { showingDetailedHistory = true }.font(
                    .system(size: 13, weight: .semibold)
                ).foregroundColor(PortfolioDesign.accentCyan)
            }

            if viewModel.recentTrades.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 40))
                        .foregroundColor(PortfolioDesign.textMuted)
                    Text("No transactions yet").font(.system(size: 15, weight: .medium))
                        .foregroundColor(PortfolioDesign.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.recentTrades.prefix(5)) { trade in
                        HStack(spacing: 14) {
                            Circle().fill(
                                trade.type == .buy
                                    ? PortfolioDesign.positive.opacity(0.2)
                                    : PortfolioDesign.negative.opacity(0.2)
                            ).frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: trade.type == .buy ? "plus" : "minus").font(
                                        .system(size: 16, weight: .bold)
                                    ).foregroundColor(
                                        trade.type == .buy
                                            ? PortfolioDesign.positive : PortfolioDesign.negative))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trade.asset.rawValue).font(.system(size: 15, weight: .bold))
                                    .foregroundColor(PortfolioDesign.textPrimary)
                                Text(trade.date, style: .date).font(
                                    .system(size: 12, weight: .medium)
                                ).foregroundColor(PortfolioDesign.textMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatCurrency(trade.quantity * trade.price)).font(
                                    .system(size: 15, weight: .bold)
                                ).foregroundColor(PortfolioDesign.textPrimary)
                                Text(trade.type == .buy ? "BUY" : "SELL").font(
                                    .system(size: 11, weight: .bold)
                                ).foregroundColor(
                                    trade.type == .buy
                                        ? PortfolioDesign.positive : PortfolioDesign.negative
                                ).padding(.horizontal, 8).padding(.vertical, 3).background(
                                    RoundedRectangle(cornerRadius: 6).fill(
                                        (trade.type == .buy
                                            ? PortfolioDesign.positive : PortfolioDesign.negative)
                                            .opacity(0.15)))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - FAB
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showingAddAsset = true
                } label: {
                    ZStack {
                        Circle().fill(PortfolioDesign.accentGradient).frame(width: 60, height: 60)
                            .shadow(
                                color: PortfolioDesign.accentPurple.opacity(0.5), radius: 16, x: 0,
                                y: 8)
                        Image(systemName: "plus").font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundView

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    PortfolioHeaderCardView(
                        portfolioManager: portfolioManager, totalValue: viewModel.totalValue,
                        dailyChange: viewModel.dailyChange,
                        dailyChangePercentage: viewModel.dailyChangePercentage, isHidden: $isHidden,
                        showingPortfolioMenu: $showingPortfolioMenu
                    )
                    .padding(.horizontal, 20)
                    .opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)

                    quickActionsSection.opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)
                    performanceChartSection.opacity(isAppearing ? 1 : 0).offset(
                        y: isAppearing ? 0 : 20)
                    allocationSection.opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)
                    PremiumSegmentControl(selectedTab: $selectedTab).opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)

                    if selectedTab == .overview {
                        assetsListSection.opacity(isAppearing ? 1 : 0).offset(
                            y: isAppearing ? 0 : 20)
                    } else {
                        transactionsSection.opacity(isAppearing ? 1 : 0).offset(
                            y: isAppearing ? 0 : 20)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .refreshable { await viewModel.refresh() }

            floatingActionButton
        }
        .sheet(isPresented: $showingPortfolioMenu) {
            PortfolioMenuView(
                portfolioManager: portfolioManager,
                showingEditPortfolio: $showingEditPortfolio,
                selectedPortfolio: $selectedPortfolio,
                showingExportOptions: $showingExportOptions,
                showingRealtimePrices: $showingRealtimePrices,
                isHidden: $isHidden,
                showingAddPortfolio: $showingAddPortfolio
            )
        }
        .sheet(isPresented: $showingAddAsset) { AddAssetSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingSortOptions) { SortOptionsView(selectedOption: $sortOption) }
        .sheet(isPresented: $showingSellAssetSheet) { SellAssetSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingFilterOptions) {
            FilterOptionsView(
                selectedAssetType: $selectedAssetType, minValue: $minValue, maxValue: $maxValue)
        }
        .sheet(isPresented: $showingDetailedHistory) {
            DetailedTradeHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingExportOptions) { ExportOptionsView() }
        .sheet(isPresented: $showingAssetAllocationDetails) {
            AllocationDetailsView(
                items: generateAssetAllocationData().sorted { $0.percentage > $1.percentage })
        }
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
        .onChange(of: selectedTimeRange) { _, _ in highlightedPortfolioPoint = nil }
    }

    // MARK: - Helpers
    private func assetColor(_ asset: AssetCode) -> Color {
        let colors: [Color] = [
            PortfolioDesign.accentPurple, PortfolioDesign.accentCyan, Color(hex: "#4CAF50"),
            Color(hex: "#FF9800"), Color(hex: "#E040FB"), Color(hex: "#00BCD4"),
        ]
        return colors[abs(asset.rawValue.hashValue) % colors.count]
    }

    private func assetIcon(_ asset: AssetCode) -> String {
        let icons = [
            "dollarsign.circle.fill", "eurosign.circle.fill", "bitcoinsign.circle.fill",
            "chart.line.uptrend.xyaxis", "star.fill", "diamond.fill",
        ]
        return icons[abs(asset.rawValue.hashValue) % icons.count]
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: value)) ?? "0.00") TL"
    }

    private func formatCurrencyShort(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    private var sortedAndFilteredAssets: [UserAsset] {
        var assets = viewModel.userAssets
        if !searchText.isEmpty {
            assets = assets.filter {
                $0.asset.rawValue.localizedCaseInsensitiveContains(searchText)
                    || $0.asset.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let type = selectedAssetType { assets = assets.filter { $0.asset == type } }
        assets = assets.filter { $0.currentValue >= minValue && $0.currentValue <= maxValue }
        switch sortOption {
        case .valueDesc: assets.sort { $0.currentValue > $1.currentValue }
        case .valueAsc: assets.sort { $0.currentValue < $1.currentValue }
        case .nameAsc: assets.sort { $0.asset.rawValue < $1.asset.rawValue }
        case .nameDesc: assets.sort { $0.asset.rawValue > $1.asset.rawValue }
        case .profitDesc:
            assets.sort { ($0.currentValue - $0.totalCost) > ($1.currentValue - $1.totalCost) }
        case .profitAsc:
            assets.sort { ($0.currentValue - $0.totalCost) < ($1.currentValue - $1.totalCost) }
        }
        return assets
    }

    private func generatePortfolioHistory() -> [PortfolioDataPoint] {
        guard !viewModel.userAssets.isEmpty else { return [] }
        let days = selectedTimeRange.days
        let now = Date()
        var points: [PortfolioDataPoint] = []
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: now) ?? now
            let variation = Double.random(in: 0.95...1.05)
            let value = viewModel.totalValue * variation
            points.append(PortfolioDataPoint(date: date, value: value))
        }
        return points.reversed()
    }

    private func generateAssetAllocationData() -> [AssetAllocationItem] {
        guard !viewModel.userAssets.isEmpty else { return [] }
        let total = max(viewModel.totalValue, 1)
        let palette: [Color] = [
            PortfolioDesign.accentPurple, PortfolioDesign.accentCyan, Color(hex: "#4CAF50"),
            Color(hex: "#FF9800"), Color(hex: "#E040FB"),
        ]
        return viewModel.userAssets.enumerated().map { index, asset in
            AssetAllocationItem(
                asset: asset.asset, value: asset.currentValue,
                percentage: (asset.currentValue / total) * 100,
                color: palette[index % palette.count])
        }
    }
}

#Preview {
    DashboardView(container: AppContainer(mockMode: true)).preferredColorScheme(.dark)
}
