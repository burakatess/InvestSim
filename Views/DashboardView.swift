import Charts
import SwiftUI

private struct AppColors {
    static let background = Color(hex: "#0A1128")
    static let cardTop = Color(hex: "#2B2F55")
    static let cardBottom = Color(hex: "#1A1C36")
    static let accentPurple = Color(hex: "#8A7CFF")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let borderSoft = Color.white.opacity(0.05)
}

enum SortOption: String, CaseIterable {
    case valueDesc = "value_high_to_low"
    case valueAsc = "value_low_to_high"
    case nameAsc = "name_a_to_z"
    case nameDesc = "name_z_to_a"
    case profitDesc = "profit_high_to_low"
    case profitAsc = "profit_low_to_high"

    var localizedTitle: String {
        switch self {
        case .valueDesc:
            return "Value (High → Low)"
        case .valueAsc:
            return "Value (Low → High)"
        case .nameAsc:
            return "Name (A → Z)"
        case .nameDesc:
            return "Name (Z → A)"
        case .profitDesc:
            return "Profit (High → Low)"
        case .profitAsc:
            return "Profit (Low → High)"
        }
    }
}

// NOTE: Canonical TabBarItem lives in Views/Components/TabBar.swift
// DashboardView still references a minimal version to avoid compile errors when the tab component isn't loaded here.
private enum TabBarItem: CaseIterable, Identifiable {
    case portfolio, plans, scenarios, prices, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .portfolio: return "Portfolio"
        case .plans: return "Plans"
        case .scenarios: return "Scenarios"
        case .prices: return "Prices"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .portfolio: return "wallet.pass"
        case .plans: return "calendar"
        case .scenarios: return "chart.bar"
        case .prices: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

private struct DashboardCard<Content: View>: View {
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
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")], startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, y: 6)
    }
}

struct DashboardView: View {
    @StateObject private var portfolioManager = PortfolioManager()
    @StateObject private var viewModel: DashboardVM
    @ObservedObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showingAddAsset = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .valueDesc
    @State private var showingSortOptions = false
    @State private var showingSellAssetSheet = false
    @State private var selectedTab: DashboardTab = .overview
    @State private var selectedSubTab: SubTab = .assets
    @State private var showingPortfolioDetails = false
    @State private var isHidden = false
    @State private var showingFilterOptions = false
    @State private var selectedAssetType: AssetCode? = nil
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 1_000_000
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTimeRange: ChartTimeRange = .month3
    @State private var showingDetailedHistory = false
    @State private var showingExportOptions = false
    @State private var showingGuestPrompt = false
    @State private var showingAddAlert = false
    @State private var showingRealtimePrices = false
    @State private var showingAssetAllocationDetails = false
    @State private var highlightedPortfolioPoint: PortfolioDataPoint?
    @State private var showingAddPortfolio = false

    init(container: AppContainer) {
        let portfolioManager = PortfolioManager()
        self._portfolioManager = StateObject(wrappedValue: portfolioManager)
        self._viewModel = StateObject(
            wrappedValue: DashboardVM(container: container, portfolioManager: portfolioManager))
    }

    // MARK: - Helper Functions
    private func assetColor(_ asset: AssetCode) -> Color {
        // Basit renk atama - tüm varlıklar için
        let colors: [Color] = [
            .blue, .green, .purple, .red, .orange, .yellow, .pink, .cyan, .mint, .indigo,
        ]
        let index = abs(asset.rawValue.hashValue) % colors.count
        return colors[index]
    }

    private func assetIcon(_ asset: AssetCode) -> String {
        // Basit icon atama - tüm varlıklar için
        let icons = [
            "dollarsign.circle.fill", "eurosign.circle.fill", "sterlingsign.circle.fill",
            "yensign.circle.fill", "diamond.fill", "circle.fill", "lira.circle.fill",
            "bitcoinsign.circle.fill", "chart.line.uptrend.xyaxis", "star.fill",
        ]
        let index = abs(asset.rawValue.hashValue) % icons.count
        return icons[index]
    }

    private var lastUpdateLabel: String {
        guard let date = viewModel.lastUpdateTime else {
            return "Unknown"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }

    private func pillButton(title: String, icon: String, action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    enum TimeRange: String, CaseIterable {
        case day24 = "24s"
        case week7 = "7g"
        case month30 = "30g"
        case month90 = "90g"
        case all = "all"

        var displayName: String {
            switch self {
            case .day24:
                return "24 Hours"
            case .week7:
                return "7 Days"
            case .month30:
                return "30 Days"
            case .month90:
                return "90 Days"
            case .all:
                return "All"
            }
        }
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
            case .all: return 1095  // 3 years
            }
        }
    }

    enum DashboardTab: String, CaseIterable {
        case overview = "overview"
        case transactions = "transactions"
        case earn = "earn"

        var displayName: String {
            switch self {
            case .overview:
                return "Overview"
            case .transactions:
                return "Transactions"
            case .earn:
                return "Earn"
            }
        }
    }

    enum SubTab: String, CaseIterable {
        case assets = "Assets"
        case totalProfit = "Total Profit"
        case allocation = "Allocation"

        var displayName: String {
            return self.rawValue
        }
    }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    PortfolioHeader(
                        portfolioManager: portfolioManager,
                        showingExportOptions: $showingExportOptions,
                        showingRealtimePrices: $showingRealtimePrices,
                        isHidden: $isHidden
                    )
                    .padding(.horizontal, 20)
                    // .padding(.top, 8) removed to tighten layout

                    portfolioSummaryView

                    quickActionsView

                    portfolioPerformanceChart

                    assetAllocationChart

                    mainTabsView

                    if selectedTab == .overview {
                        assetsContent
                    } else {
                        transactionsContent
                    }
                }
                .padding(.bottom, 20)
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .overlay(
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddAsset = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.blue.gradient)
                                    .shadow(
                                        color: Color.blue.opacity(0.3),
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        )
        .sheet(isPresented: $showingAddAsset) {
            AddAssetSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSortOptions) {
            SortOptionsView(selectedOption: $sortOption)
        }
        .sheet(isPresented: $showingSellAssetSheet) {
            SellAssetSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingFilterOptions) {
            FilterOptionsView(
                selectedAssetType: $selectedAssetType,
                minValue: $minValue,
                maxValue: $maxValue
            )
        }
        .sheet(isPresented: $showingDetailedHistory) {
            DetailedTradeHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView()
        }
        .sheet(isPresented: $showingAddAlert) {
            Text("Price Alert - Coming Soon!")
                .padding()
        }
        .sheet(isPresented: $showingRealtimePrices) {
            Text("Realtime Prices - Coming Soon!")
                .padding()
        }
        .sheet(isPresented: $showingGuestPrompt) {
            Text("Registration required for profile")
                .padding()
        }
        .sheet(isPresented: $showingAssetAllocationDetails) {
            AllocationDetailsView(
                items: generateAssetAllocationData().sorted { $0.percentage > $1.percentage })
        }
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
        .onChange(of: selectedTimeRange) { _, _ in
            highlightedPortfolioPoint = nil
        }
    }

    // MARK: - Assets Content
    private var assetsContent: some View {
        DashboardCard(spacing: 20) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.accentPurple)
                    TextField("Search assets...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(AppColors.textPrimary)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    pillButton(title: "Filter", icon: "line.3.horizontal.decrease.circle") {
                        showingFilterOptions = true
                    }

                    pillButton(title: sortOption.localizedTitle, icon: "arrow.up.arrow.down") {
                        showingSortOptions = true
                    }
                }
            }

            if sortedAndFilteredAssets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary)
                    Text(searchText.isEmpty ? "No assets added yet" : "Asset not found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(sortedAndFilteredAssets.enumerated()), id: \.element.id) {
                        index, asset in
                        assetRowView(asset)
                        if index < sortedAndFilteredAssets.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var quickActionsView: some View {
        DashboardCard(spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 12) {
                quickActionButton(title: "Add Asset", icon: "plus") {
                    showingAddAsset = true
                }

                quickActionButton(title: "Sell Asset", icon: "minus") {
                    showingSellAssetSheet = true
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 12)
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(
                colors: title == "Add Asset"
                    ? [Color(hex: "#3B82F6"), Color(hex: "#2563EB")]
                    : [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: (title == "Add Asset" ? Color(hex: "#3B82F6") : Color(hex: "#EF4444")).opacity(
                0.45),
            radius: 25,
            x: 0,
            y: 6
        )
        .contentShape(Rectangle())
    }

    private var mainTabsView: some View {
        HStack(spacing: 0) {
            tabButton(title: "My Assets", tab: .overview)
            tabButton(title: "Transactions", tab: .transactions)
        }
        .padding(.horizontal, 20)
    }

    private func tabButton(title: String, tab: DashboardTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(
                        selectedTab == tab ? AppColors.textPrimary : AppColors.textSecondary)

                Rectangle()
                    .fill(selectedTab == tab ? AppColors.accentPurple : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transactions Content
    private var transactionsContent: some View {
        DashboardCard(spacing: 16) {
            HStack {
                Text("Transaction History")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Detailed View") {
                    showingDetailedHistory = true
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            }

            if viewModel.recentTrades.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No transactions yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentTrades.enumerated()), id: \.element.id) {
                        index, trade in
                        transactionRowView(trade)
                        if index < viewModel.recentTrades.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func transactionRowView(_ trade: Trade) -> some View {
        HStack(spacing: 16) {
            // İşlem Türü İkonu
            Circle()
                .fill(trade.type == .buy ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: trade.type == .buy ? "plus" : "minus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(trade.type == .buy ? .green : .red)
                )

            // İşlem Detayları
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.asset.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(trade.type == .buy ? "Buy" : "Sell")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(trade.type == .buy ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    trade.type == .buy
                                        ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            "Quantity: \(String(format: "%.4f", trade.quantity)) \(trade.asset.rawValue)"
                        )
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.textSecondary)

                        Text("Unit Price: \(String(format: "%.2f", trade.price)) USD")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total: \(String(format: "%.2f", trade.quantity * trade.price)) USD")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)

                        Text(trade.date, style: .date)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)

                        Text(trade.date, style: .time)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Asset Row
    private func assetRowView(_ asset: UserAsset) -> some View {
        let weight = max(min(asset.currentValue / max(viewModel.totalValue, 1), 1), 0)

        return HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(assetColor(asset.asset).opacity(0.25))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: assetIcon(asset.asset))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.asset.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(asset.asset.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Unit Price")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text(isHidden ? "••••" : formatCurrency(asset.currentPrice, decimals: 2))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Text(isHidden ? "••••••••" : formatCurrency(asset.currentValue, decimals: 2))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .animation(.easeInOut(duration: 0.25), value: isHidden)

                HStack(spacing: 6) {
                    Text("\(String(format: "%.2f", asset.quantity)) units")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    if viewModel.totalValue > 0 {
                        Text(String(format: "• %.1f%%", weight * 100))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")], startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.4), radius: 14, y: 4)
    }

    // MARK: - Portfolio Summary Card
    private var portfolioSummaryView: some View {
        let changeValue = viewModel.dailyChange
        let changePercentage = viewModel.dailyChangePercentage
        let changeIcon =
            changeValue > 0 ? "arrow.up.right" : (changeValue < 0 ? "arrow.down.right" : "minus")
        let changePrefix = changeValue > 0 ? "+" : ""

        return VStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Portfolio Summary")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button(action: { isHidden.toggle() }) {
                        Image(systemName: isHidden ? "eye.slash" : "eye")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .bottom, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total Portfolio Value")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)

                        Text(isHidden ? "••••••••" : totalPortfolioValueString)
                            .font(.system(size: 50, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color(hex: "#A78BFA")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 16, y: 4)
                            .animation(.easeInOut(duration: 0.25), value: isHidden)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Daily Change")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 8) {
                            Image(systemName: changeIcon)
                                .font(.system(size: 12, weight: .bold))
                            Text(isHidden ? "••••" : formatCurrency(changeValue, decimals: 2))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(AppColors.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(changeColor.opacity(0.18))
                        )

                        Text(
                            isHidden
                                ? "••%" : String(format: "%@%.2f%%", changePrefix, changePercentage)
                        )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(changeColor)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 165, maxHeight: 200)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")], startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, 20)
    }

    private var totalPortfolioValueString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: viewModel.totalValue)) ?? "0,00"
        return "\(formatted) TL"
    }

    private var portfolioPerformanceChart: some View {
        let history = generatePortfolioHistory()

        return DashboardCard(spacing: 18) {
            HStack(alignment: .center) {
                Text("Portfolio Performance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ChartTimeRange.allCases, id: \.self) { period in
                            let isActive = selectedTimeRange == period
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedTimeRange = period
                                }
                            } label: {
                                Text(period.rawValue)
                                    .font(.caption.bold())
                                    .frame(width: 44, height: 32)
                                    .foregroundColor(isActive ? .white : Color.white.opacity(0.85))
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                isActive
                                                    ? Color(hex: "#7C4DFF").opacity(0.14)
                                                    : Color.white.opacity(0.12)
                                            )
                                            .overlay(
                                                RoundedRectangle(
                                                    cornerRadius: 10, style: .continuous
                                                )
                                                .stroke(
                                                    isActive
                                                        ? Color(hex: "#7C4DFF")
                                                        : Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if viewModel.userAssets.isEmpty || history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)

                    Text("No assets added yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Text("Add assets to create your portfolio chart")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 130)
            } else {
                ZStack(alignment: .topTrailing) {
                    Chart {
                        ForEach(history, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(AppColors.accentPurple)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        AppColors.accentPurple.opacity(0.14),
                                        AppColors.accentPurple.opacity(0.01),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }

                        if let selectedPoint = highlightedPortfolioPoint {
                            RuleMark(x: .value("Date", selectedPoint.date))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(AppColors.accentPurple.opacity(0.6))

                            PointMark(
                                x: .value("Date", selectedPoint.date),
                                y: .value("Value", selectedPoint.value)
                            )
                            .symbolSize(70)
                            .foregroundStyle(AppColors.accentPurple)
                        }
                    }
                    .frame(height: 112)
                    .chartXAxis {
                        AxisMarks(
                            values: .stride(by: .day, count: max(selectedTimeRange.days / 5, 1))
                        ) { value in
                            AxisGridLine().foregroundStyle(AppColors.borderSoft)
                            AxisValueLabel(format: .dateTime.month().day())
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(AppColors.borderSoft)
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(formatCurrency(doubleValue))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            let plotRect = geo[plotFrame]
                                            let locationX = value.location.x - plotRect.origin.x
                                            guard locationX >= 0, locationX <= plotRect.size.width
                                            else { return }
                                            if let date: Date = proxy.value(atX: locationX) {
                                                highlightedPortfolioPoint = history.min {
                                                    lhs, rhs in
                                                    abs(lhs.date.timeIntervalSince(date))
                                                        < abs(rhs.date.timeIntervalSince(date))
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                highlightedPortfolioPoint = nil
                                            }
                                        }
                                )
                        }
                    }

                    if let selectedPoint = highlightedPortfolioPoint {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatCurrency(selectedPoint.value))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                            Text(selectedPoint.date, format: .dateTime.day().month().year())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var assetAllocationChart: some View {
        let allocationData = generateAssetAllocationData()

        return DashboardCard(spacing: 18) {
            HStack {
                Text("Asset Allocation")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button(action: {
                    if !allocationData.isEmpty {
                        showingAssetAllocationDetails = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Go to Details")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if allocationData.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No assets added yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                HStack(spacing: 8) {
                    Chart(allocationData) { item in
                        SectorMark(
                            angle: .value("Weight", item.value),
                            innerRadius: .ratio(0.72),
                            outerRadius: .ratio(0.98),
                            angularInset: 0.8
                        )
                        .cornerRadius(4)
                        .foregroundStyle(item.color)
                    }
                    .frame(width: 160, height: 160)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(allocationData.sorted { $0.percentage > $1.percentage }) { item in
                            HStack(alignment: .center, spacing: 10) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)

                                Text(
                                    "\(item.asset.symbol) · \(String(format: "%.1f%%", item.percentage)) · \(formatCurrency(item.value))"
                                )
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .allowsTightening(true)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func generateAssetAllocationData() -> [AssetAllocationItem] {
        guard !viewModel.userAssets.isEmpty else { return [] }

        let totalValue = max(viewModel.totalValue, 1)
        let palette: [Color] = [
            Color(hex: "#7C4DFF").opacity(0.85),
            Color(hex: "#4CC9F0").opacity(0.85),
            Color(hex: "#4361EE").opacity(0.85),
            Color(hex: "#3A0CA3").opacity(0.85),
        ]

        return viewModel.userAssets.enumerated().map { index, asset in
            let percentage = (asset.currentValue / totalValue) * 100
            return AssetAllocationItem(
                asset: asset.asset,
                value: asset.currentValue,
                percentage: percentage,
                color: palette[index % palette.count]
            )
        }
    }

    // MARK: - Performance Calculations
    private func calculateROI() -> Double {
        guard !viewModel.userAssets.isEmpty else { return 0.0 }

        let totalCost = viewModel.userAssets.reduce(0) { $0 + $1.totalCost }
        let totalValue = viewModel.totalValue

        guard totalCost > 0 else { return 0.0 }
        return ((totalValue - totalCost) / totalCost) * 100
    }

    private func calculateVolatility() -> Double {
        // Basit volatilite hesaplama - gerçek uygulamada daha karmaşık olmalı
        let portfolioHistory = generatePortfolioHistory()
        guard portfolioHistory.count > 1 else { return 0.0 }

        let returns = portfolioHistory.enumerated().compactMap { (index, point) -> Double? in
            guard index > 0 else { return nil }
            let previousValue = portfolioHistory[index - 1].value
            return (point.value - previousValue) / previousValue
        }

        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count)
        return sqrt(variance) * 100
    }

    private func calculateSharpeRatio() -> Double {
        let roi = calculateROI()
        let volatility = calculateVolatility()

        guard volatility > 0 else { return 0.0 }
        // Risk-free rate olarak %10 varsayıyoruz (Türkiye için)
        let riskFreeRate = 10.0
        return (roi - riskFreeRate) / volatility
    }

    private func calculateMaxDrawdown() -> Double {
        let portfolioHistory = generatePortfolioHistory()
        guard portfolioHistory.count > 1 else { return 0.0 }

        var maxValue = portfolioHistory[0].value
        var maxDrawdown = 0.0

        for point in portfolioHistory {
            if point.value > maxValue {
                maxValue = point.value
            }
            let drawdown = ((maxValue - point.value) / maxValue) * 100
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }

        return maxDrawdown
    }

    // MARK: - Asset Performance Calculation
    private func calculateAssetPerformance(_ asset: UserAsset) -> (
        percentage: Double, isPositive: Bool
    ) {
        let percentage = asset.priceChangePercentage
        return (percentage: percentage, isPositive: percentage >= 0)
    }

    // MARK: - Helper Functions
    private var sortedAndFilteredAssets: [UserAsset] {
        let filtered = viewModel.userAssets.filter { asset in
            // Search filter
            let matchesSearch =
                searchText.isEmpty
                || asset.asset.rawValue.localizedCaseInsensitiveContains(searchText)

            // Asset type filter
            let matchesAssetType = selectedAssetType == nil || asset.asset == selectedAssetType

            // Value range filter
            let matchesValueRange = asset.currentValue >= minValue && asset.currentValue <= maxValue

            return matchesSearch && matchesAssetType && matchesValueRange
        }

        return filtered.sorted { asset1, asset2 in
            switch sortOption {
            case .valueDesc:
                return asset1.currentValue > asset2.currentValue
            case .valueAsc:
                return asset1.currentValue < asset2.currentValue
            case .nameAsc:
                return asset1.asset.rawValue < asset2.asset.rawValue
            case .nameDesc:
                return asset1.asset.rawValue > asset2.asset.rawValue
            case .profitDesc:
                return asset1.profitLoss > asset2.profitLoss
            case .profitAsc:
                return asset1.profitLoss < asset2.profitLoss
            }
        }
    }

    private var changeColor: Color {
        if viewModel.dailyChange > 0 {
            return Color(hex: "#16A34A")  // Yeşil
        } else if viewModel.dailyChange < 0 {
            return Color(hex: "#DC2626")  // Kırmızı
        } else {
            return Color(hex: "#6B7280")  // Gri
        }
    }

    private var profitColor: Color {
        if viewModel.totalProfit > 0 {
            return Color(hex: "#16A34A")  // Yeşil
        } else if viewModel.totalProfit < 0 {
            return Color(hex: "#DC2626")  // Kırmızı
        } else {
            return Color(hex: "#6B7280")  // Gri
        }
    }

    private func changeColor(_ asset: UserAsset) -> Color {
        if asset.priceChange > 0 {
            return Color(hex: "#16A34A")  // Yeşil
        } else if asset.priceChange < 0 {
            return Color(hex: "#DC2626")  // Kırmızı
        } else {
            return Color(hex: "#6B7280")  // Gri
        }
    }

    private func formatCurrency(_ value: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.currencySymbol = ""
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals

        let formatted = formatter.string(from: NSNumber(value: value)) ?? "0,00"
        return "\(formatted) TL"
    }

    // MARK: - Portfolio History Generation
    private func generatePortfolioHistory() -> [PortfolioDataPoint] {
        guard !viewModel.userAssets.isEmpty else { return [] }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate =
            calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate

        var dataPoints: [PortfolioDataPoint] = []
        let totalDays = selectedTimeRange.days

        // Zaman dilimine göre veri noktası sıklığını ayarla
        let stepSize = max(1, totalDays / 50)  // Maksimum 50 nokta

        for i in stride(from: 0, through: totalDays, by: stepSize) {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let portfolioValue = calculatePortfolioValue(for: date)
                dataPoints.append(PortfolioDataPoint(date: date, value: portfolioValue))
            }
        }

        return dataPoints
    }

    private func calculatePortfolioValue(for date: Date) -> Double {
        // Basit simülasyon - gerçek uygulamada fiyat geçmişi kullanılmalı
        let baseValue = viewModel.userAssets.reduce(0) { $0 + $1.currentValue }
        let daysSinceStart =
            Calendar.current.dateComponents(
                [.day], from: Date().addingTimeInterval(-90 * 24 * 60 * 60), to: date
            ).day ?? 0
        let volatility = 0.02  // %2 günlük volatilite
        let trend = 0.001  // %0.1 günlük trend

        let randomFactor = Double.random(in: -volatility...volatility)
        let trendFactor = Double(daysSinceStart) * trend

        return baseValue * (1 + randomFactor + trendFactor)
    }

}

// MARK: - Portfolio Data Point
struct PortfolioDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Asset Allocation Item
struct AssetAllocationItem: Identifiable {
    let id = UUID()
    let asset: AssetCode
    let value: Double
    let percentage: Double
    let color: Color
}

struct AllocationDetailsView: View {
    let items: [AssetAllocationItem]
    @Environment(\.dismiss) private var dismiss

    private var sortedItems: [AssetAllocationItem] {
        items.sorted { $0.percentage > $1.percentage }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(sortedItems) { item in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(item.color.opacity(0.7))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: allocationIcon(for: item.asset))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.asset.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(item.asset.symbol)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "%.1f%%", item.percentage))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(formatCurrency(item.value))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppColors.borderSoft, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Allocation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func allocationIcon(for asset: AssetCode) -> String {
        let icons = [
            "bitcoinsign.circle.fill",
            "chart.line.uptrend.xyaxis",
            "dollarsign.circle.fill",
            "star.fill",
            "globe",
            "lira.circle.fill",
        ]
        let index = abs(asset.rawValue.hashValue) % icons.count
        return icons[index]
    }

    private func formatCurrency(_ value: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "0,00"
        return "\(formatted) TL"
    }
}

// MARK: - Sort Options View
struct SortOptionsView: View {
    @Binding var selectedOption: SortOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            let isActive = selectedOption == option
                            Button(action: {
                                selectedOption = option
                                dismiss()
                            }) {
                                HStack {
                                    Text(option.localizedTitle)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accentPurple)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            isActive ? AppColors.accentPurple : Color.clear,
                                            lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Asset Transaction Sheet
struct AssetTransactionSheet: View {
    @ObservedObject var viewModel: DashboardVM
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAsset: AssetCode = .USD
    @State private var quantity: String = ""
    @State private var unitPrice: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var transactionType: TransactionType = .buy

    enum TransactionType {
        case buy, sell

        var title: String {
            switch self {
            case .buy: return "Add Asset"
            case .sell: return "Remove Asset"
            }
        }

        var buttonTitle: String {
            switch self {
            case .buy: return "Add"
            case .sell: return "Remove"
            }
        }

        var buttonColor: Color {
            switch self {
            case .buy: return .blue
            case .sell: return .red
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    // Transaction Type Selector
                    HStack(spacing: 0) {
                        Button(action: {
                            transactionType = .buy
                        }) {
                            Text("Add")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(transactionType == .buy ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            transactionType == .buy
                                                ? Color.blue : Color.gray.opacity(0.2))
                                )
                        }

                        Button(action: {
                            transactionType = .sell
                        }) {
                            Text("Remove")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(transactionType == .sell ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            transactionType == .sell
                                                ? Color.red : Color.gray.opacity(0.2))
                                )
                        }
                    }
                    .padding(.horizontal, 4)

                    // Asset Selection Dropdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Asset")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Menu {
                            ForEach(AssetCode.allCases, id: \.self) { asset in
                                Button(action: {
                                    selectedAsset = asset
                                }) {
                                    HStack {
                                        Text(asset.rawValue)
                                        if selectedAsset == asset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedAsset.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }

                    // Quantity Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quantity")
                            .font(.headline)
                            .fontWeight(.semibold)

                        NumberTextField(text: $quantity, placeholder: "Enter quantity")
                    }

                    // Unit Price Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unit Price (₺)")
                            .font(.headline)
                            .fontWeight(.semibold)

                        NumberTextField(text: $unitPrice, placeholder: "Enter unit price")
                    }

                    Spacer()

                    // Action Button
                    Button(action: {
                        if transactionType == .buy {
                            addAsset()
                        } else {
                            sellAsset()
                        }
                    }) {
                        Text(transactionType.buttonTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(transactionType.buttonColor)
                            .cornerRadius(12)
                    }
                    .disabled(quantity.isEmpty || unitPrice.isEmpty)
                }
                .padding()
            }
            .navigationTitle(transactionType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert(isSuccess ? "Success" : "Error", isPresented: $showingAlert) {
            Button("OK") {
                if isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func addAsset() {
        print("🚀🚀🚀 FORM addAsset FONKSİYONU ÇAĞRILDI! 🚀🚀🚀")
        print("🚀 Seçilen varlık: \(selectedAsset)")
        print("🚀 Miktar: \(quantity)")
        print("🚀 Birim fiyat: \(unitPrice)")

        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            print("❌ Invalid amount: \(quantity)")
            alertMessage = "Enter a valid amount"
            showingAlert = true
            return
        }

        guard let unitPriceValue = Double(unitPrice), unitPriceValue > 0 else {
            print("❌ Invalid unit price: \(unitPrice)")
            alertMessage = "Enter a valid unit price"
            showingAlert = true
            return
        }

        print("✅ Form validasyonu başarılı, viewModel.addAsset çağrılıyor...")
        Task {
            await viewModel.addAsset(
                asset: selectedAsset,
                quantity: quantityValue,
                unitPrice: unitPriceValue,
                date: Date()
            )

            await MainActor.run {
                alertMessage = "Asset successfully added!"
                isSuccess = true
                showingAlert = true
            }
        }
    }

    private func sellAsset() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            alertMessage = "Enter a valid amount"
            showingAlert = true
            return
        }

        guard let unitPriceValue = Double(unitPrice), unitPriceValue > 0 else {
            alertMessage = "Enter a valid unit price"
            showingAlert = true
            return
        }

        // Mevcut varlık miktarını kontrol et
        let existingAsset = viewModel.userAssets.first { $0.asset == selectedAsset }
        if let existing = existingAsset {
            if quantityValue > existing.quantity {
                alertMessage =
                    "Satış miktarı mevcut bakiyeden fazla olamaz. Mevcut bakiye: \(String(format: "%.4f", existing.quantity))"
                showingAlert = true
                return
            }
        } else {
            alertMessage = "Satılacak varlık bulunamadı"
            showingAlert = true
            return
        }

        Task {
            await viewModel.sellAsset(
                asset: selectedAsset,
                quantity: quantityValue,
                unitPrice: unitPriceValue,
                date: Date()
            )

            await MainActor.run {
                alertMessage = "Varlık başarıyla çıkarıldı!"
                isSuccess = true
                showingAlert = true
            }
        }
    }
}

// MARK: - Number Text Field
struct NumberTextField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.decimalPad)
            .onChange(of: text) { _, newValue in
                // Sadece sayı ve virgül karakterlerine izin ver
                let filtered = newValue.filter { character in
                    character.isNumber || character == ","
                }
                // 12 karakter sınırı uygula
                let limited = String(filtered.prefix(12))
                if limited != newValue {
                    text = limited
                }
            }
    }
}

// MARK: - Sell Asset Sheet
struct SellAssetSheet: View {
    @ObservedObject var viewModel: DashboardVM
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAssetId: UUID?
    @State private var quantityText: String = ""
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private var assets: [UserAsset] {
        viewModel.userAssets
    }

    private var selectedAsset: UserAsset? {
        if let id = selectedAssetId, let match = assets.first(where: { $0.id == id }) {
            return match
        }
        return assets.first
    }

    private var parsedQuantity: Double? {
        let sanitized = quantityText.replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    if assets.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Portföyünüzde satılacak varlık bulunmuyor")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    } else {
                        assetPickerSection

                        if let asset = selectedAsset {
                            availableInfo(for: asset)
                            amountInput(for: asset)

                            if let message = errorMessage {
                                Text(message)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: {
                                Task { await handleSell(for: asset) }
                            }) {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .progressViewStyle(
                                                CircularProgressViewStyle(tint: .white))
                                    }
                                    Text("Satışı Onayla")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#F87171"), Color(hex: "#DC2626")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(isProcessing)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Sell Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .onChange(of: selectedAssetId) { _, _ in
            quantityText = ""
            errorMessage = nil
        }
        .onChange(of: quantityText) { _, _ in
            errorMessage = nil
        }
    }

    @ViewBuilder
    private var assetPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Satılacak Varlık")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(assets) { asset in
                        let isActive = selectedAsset?.id == asset.id
                        Button(action: {
                            selectedAssetId = asset.id
                        }) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(chipColor(for: asset.asset).opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: chipIcon(for: asset.asset))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.asset.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(asset.asset.displayName)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        isActive
                                            ? Color.white.opacity(0.12) : Color.white.opacity(0.04)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                isActive ? AppColors.accentPurple : Color.clear,
                                                lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func availableInfo(for asset: UserAsset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Available Amount")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            HStack {
                Text("\(String(format: "%.4f", asset.quantity)) \(asset.asset.rawValue)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(formatCurrency(asset.currentValue, decimals: 2))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func amountInput(for asset: UserAsset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount to Sell")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            HStack {
                TextField("0", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .foregroundColor(AppColors.textPrimary)
                Button("All") {
                    quantityText = String(format: "%.4f", asset.quantity)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.accentPurple)
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func handleSell(for asset: UserAsset) async {
        guard let amount = parsedQuantity, amount > 0 else {
            errorMessage = "Enter a valid amount."
            return
        }

        guard amount <= asset.quantity + 1e-6 else {
            errorMessage = "Amount cannot exceed available balance."
            return
        }

        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        await viewModel.sellAsset(
            asset: asset.asset,
            quantity: amount,
            unitPrice: asset.currentPrice,
            date: Date()
        )

        await MainActor.run {
            dismiss()
        }
    }

    private func formatCurrency(_ value: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "0,00"
        return "\(formatted) TL"
    }

    private func chipColor(for asset: AssetCode) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .red, .orange, .pink, .cyan, .mint, .indigo]
        let index = abs(asset.rawValue.hashValue) % colors.count
        return colors[index]
    }

    private func chipIcon(for asset: AssetCode) -> String {
        let icons = [
            "dollarsign.circle.fill",
            "eurosign.circle.fill",
            "sterlingsign.circle.fill",
            "yensign.circle.fill",
            "diamond.fill",
            "circle.fill",
            "lira.circle.fill",
            "bitcoinsign.circle.fill",
            "chart.line.uptrend.xyaxis",
            "star.fill",
        ]
        let index = abs(asset.rawValue.hashValue) % icons.count
        return icons[index]
    }
}

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct ExportOption: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let gradient: [Color]
    }

    private var options: [ExportOption] {
        [
            ExportOption(
                title: "CSV Olarak Dışa Aktar",
                subtitle: "Tüm işlem geçmişini Excel uyumlu formatta alın",
                icon: "doc.text",
                gradient: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")]
            ),
            ExportOption(
                title: "PDF Performans Raporu",
                subtitle: "Güncel portföy durumunu PDF raporu olarak paylaşın",
                icon: "doc.richtext",
                gradient: [Color(hex: "#8C5AE8"), Color(hex: "#6C2BD9")]
            ),
            ExportOption(
                title: "JSON Veri Paketi",
                subtitle: "Geliştiriciler için ham veri çıktısı",
                icon: "chevron.left.forwardslash.chevron.right",
                gradient: [Color(hex: "#22D3EE"), Color(hex: "#0EA5E9")]
            ),
        ]
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#050B1F"), Color(hex: "#111736")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Portföyü Aktar")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            Text(
                                "Verilerinizi paylaşmak veya yedeklemek için bir format seçin. Tüm dışa aktarmalar şifrelenmiş bağlantılar üzerinden hazırlanır."
                            )
                            .font(.callout)
                            .foregroundColor(Color.white.opacity(0.7))
                        }

                        VStack(spacing: 16) {
                            ForEach(options) { option in
                                Button(action: {}) {
                                    HStack(alignment: .center, spacing: 16) {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: option.gradient,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                            )
                                            .frame(width: 54, height: 54)
                                            .overlay(
                                                Image(systemName: option.icon)
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundColor(.white)
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(option.title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.9)
                                            Text(option.subtitle)
                                                .font(.subheadline)
                                                .foregroundColor(Color.white.opacity(0.6))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color.white.opacity(0.6))
                                    }
                                    .padding(18)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Güvenlik Notu")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(
                                "Tüm raporlar 24 saat boyunca indirilebilir. Dışa aktarılan dosyalar yalnızca sizin şifrenizle açılabilir."
                            )
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.65))
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Metric Card Component (scoped)
// MARK: - Filter Options View
struct FilterOptionsView: View {
    @Binding var selectedAssetType: AssetCode?
    @Binding var minValue: Double
    @Binding var maxValue: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        assetTypeSection
                        valueRangeSection
                        actionButtons
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private var assetTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Varlık Türü")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AssetCode.allCases, id: \.self) { assetType in
                    let isActive = selectedAssetType == assetType
                    Button(action: {
                        selectedAssetType = isActive ? nil : assetType
                    }) {
                        HStack {
                            Text(assetType.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accentPurple)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    isActive
                                        ? AppColors.accentPurple.opacity(0.3)
                                        : Color.white.opacity(0.04)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            isActive ? AppColors.accentPurple : Color.clear,
                                            lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var valueRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Değer Aralığı")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack {
                Text("Min: \(String(format: "%.0f", minValue)) TL")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Max: \(String(format: "%.0f", maxValue)) TL")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Min Değer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    TextField("Min", value: $minValue, format: .number)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(width: 120)
                }

                HStack {
                    Text("Max Değer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    TextField("Max", value: $maxValue, format: .number)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(width: 120)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Temizle") {
                selectedAssetType = nil
                minValue = 0
                maxValue = 1_000_000
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button("Uygula") {
                dismiss()
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [AppColors.accentPurple, Color(hex: "#7E5CEF")],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Quick Stat Card Component
struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

// MARK: - Detailed Trade History View
struct DetailedTradeHistoryView: View {
    @ObservedObject var viewModel: DashboardVM
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: TradeFilter = .all
    @State private var searchText = ""

    enum TradeFilter: String, CaseIterable {
        case all = "all"
        case buy = "buy"
        case sell = "sell"
        case today = "today"
        case week = "this_week"
        case month = "this_month"

        var displayName: String {
            switch self {
            case .all:
                return "Tümü"
            case .buy:
                return "Alış"
            case .sell:
                return "Satış"
            case .today:
                return "Bugün"
            case .week:
                return "Bu Hafta"
            case .month:
                return "Bu Ay"
            }
        }
    }

    var filteredTrades: [Trade] {
        var trades = viewModel.recentTrades

        // Debug log
        print("🔍 DetailedTradeHistoryView - recentTrades.count: \(viewModel.recentTrades.count)")
        print("🔍 DetailedTradeHistoryView - selectedFilter: \(selectedFilter)")

        // Filter by type
        switch selectedFilter {
        case .all:
            break
        case .buy:
            trades = trades.filter { $0.type == .buy }
            print("🔍 Alış filtresi uygulandı - sonuç: \(trades.count) adet")
        case .sell:
            trades = trades.filter { $0.type == .sell }
            print("🔍 Satış filtresi uygulandı - sonuç: \(trades.count) adet")
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            trades = trades.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        case .week:
            let weekAgo =
                Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            trades = trades.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            trades = trades.filter { $0.date >= monthAgo }
        }

        // Search filter
        if !searchText.isEmpty {
            trades = trades.filter { trade in
                trade.asset.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        print("🔍 Filtrelenmiş işlemler: \(trades.count) adet")
        return trades.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))

                    TextField("İşlem ara...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TradeFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                            }) {
                                Text(filter.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(
                                        selectedFilter == filter ? .white : Color.white.opacity(0.7)
                                    )
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(
                                                selectedFilter == filter
                                                    ? Color(hex: "#7C4DFF").opacity(0.25)
                                                    : Color.white.opacity(0.08)
                                            )
                                            .overlay(
                                                RoundedRectangle(
                                                    cornerRadius: 18, style: .continuous
                                                )
                                                .stroke(
                                                    selectedFilter == filter
                                                        ? Color(hex: "#7C4DFF") : Color.clear,
                                                    lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)

                // Trades List
                if filteredTrades.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))

                        Text(
                            searchText.isEmpty
                                ? "Bu filtrede işlem bulunamadı" : "Arama sonucu bulunamadı"
                        )
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                        if !searchText.isEmpty {
                            Text("'\(searchText)' için sonuç bulunamadı")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
                } else {
                    List(filteredTrades) { trade in
                        DetailedTradeRowView(trade: trade)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppColors.background.opacity(0.9), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        // Export functionality
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#7C4DFF"))
                }
            }
        }
    }
}

// MARK: - Detailed Trade Row View
struct DetailedTradeRowView: View {
    let trade: Trade

    var body: some View {
        HStack(spacing: 16) {
            // Asset Icon
            Circle()
                .fill(assetColor(trade.asset))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: assetIcon(trade.asset))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Trade Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.asset.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(trade.type == .buy ? "Alış" : "Satış")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(trade.type == .buy ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    trade.type == .buy
                                        ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            "Miktar: \(String(format: "%.4f", trade.quantity)) \(trade.asset.rawValue)"
                        )
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                        Text("Birim Fiyat: \(String(format: "%.2f", trade.price)) TL")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Toplam: \(String(format: "%.2f", trade.quantity * trade.price)) TL")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)

                        Text(trade.date, style: .date)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)

                        Text(trade.date, style: .time)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 4)
    }

    private func assetColor(_ asset: AssetCode) -> Color {
        // Basit renk atama - tüm varlıklar için
        let colors: [Color] = [
            .blue, .green, .purple, .red, .orange, .yellow, .pink, .cyan, .mint, .indigo,
        ]
        let index = abs(asset.rawValue.hashValue) % colors.count
        return colors[index]
    }

    private func assetIcon(_ asset: AssetCode) -> String {
        // Basit icon atama - tüm varlıklar için
        let icons = [
            "dollarsign.circle.fill", "eurosign.circle.fill", "sterlingsign.circle.fill",
            "yensign.circle.fill", "diamond.fill", "circle.fill", "lira.circle.fill",
            "bitcoinsign.circle.fill", "chart.line.uptrend.xyaxis", "star.fill",
        ]
        let index = abs(asset.rawValue.hashValue) % icons.count
        return icons[index]
    }
}

#Preview {
    DashboardView(container: AppContainer(mockMode: true))
}
