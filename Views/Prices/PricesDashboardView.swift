import SwiftUI

private enum PricesTheme {
    static let backgroundTop = Color(hex: "#040917")
    static let backgroundBottom = Color(hex: "#0F1836")
    static let surface = Color(hex: "#0F1C3B")
    static let surfaceElevated = Color(hex: "#192552")
    static let controlBackground = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.12)
    static let chipBorder = Color.white.opacity(0.18)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.75)
    static let textMuted = Color.white.opacity(0.55)
    static let accentPrimary = Color(hex: "#7C83FF")
    static let accentSecondary = Color(hex: "#2ED3B7")
    static let positive = Color(hex: "#45E0A8")
    static let negative = Color(hex: "#FF6B6B")
    static let warningBackground = Color(hex: "#2A161B")

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [surface, surfaceElevated],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accentPrimary, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct PricesDashboardView: View {
    @StateObject private var viewModel: PricesViewModel
    @State private var hasAppeared = false
    @State private var visibleAssets: [String: String] = [:]
    @State private var priceRefreshTimer: Timer?
    private let container: AppContainer

    init(container: AppContainer? = nil) {
        let resolvedContainer = container ?? AppContainer(mockMode: true)
        self.container = resolvedContainer
        _viewModel = StateObject(
            wrappedValue: PricesViewModel(
                assetRepository: resolvedContainer.assetRepository,
                priceManager: resolvedContainer.priceManager
            ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PricesTheme.backgroundGradient
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        searchBar
                        filterSection
                        sortSection
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                        contentSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { EmptyToolbarContent() }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                // Auto-sync assets and start price refresh
                Task {
                    await AssetCatalogManager.shared.forceSync()
                    viewModel.refreshPrices()
                }
                // Start 30-second refresh timer
                priceRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
                    _ in
                    Task { @MainActor in
                        viewModel.refreshPrices()
                    }
                }
            }
            .onDisappear {
                priceRefreshTimer?.invalidate()
                priceRefreshTimer = nil
            }
        }
    }
}

extension PricesDashboardView {
    fileprivate var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prices")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(PricesTheme.textPrimary)
            HStack {
                Text("View real-time market data")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(PricesTheme.textSecondary)
                Spacer()
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated: \(lastUpdated, style: .time)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PricesTheme.textMuted)
                }
            }
        }
    }

    fileprivate func headerButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PricesTheme.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PricesTheme.controlBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PricesTheme.border, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    fileprivate var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(PricesTheme.textMuted)
            TextField("Search assets (BTC, gold, stock...)", text: $viewModel.searchText)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(PricesTheme.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PricesTheme.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PricesTheme.border, lineWidth: 1)
                )
        )
    }

    fileprivate var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filterOptions) { option in
                    let isSelected: Bool = {
                        if option.isFavorites { return viewModel.showFavoritesOnly }
                        if let category = option.category {
                            return !viewModel.showFavoritesOnly
                                && viewModel.selectedCategory == category
                        }
                        return !viewModel.showFavoritesOnly && viewModel.selectedCategory == nil
                    }()

                    Button {
                        if option.isFavorites {
                            viewModel.showFavoritesOnly = true
                            viewModel.selectedCategory = nil
                        } else {
                            viewModel.showFavoritesOnly = false
                            viewModel.selectedCategory = option.category
                        }
                    } label: {
                        Text(option.title)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .frame(minHeight: 34)
                            .background(
                                Capsule()
                                    .fill(PricesTheme.controlBackground)
                                    .overlay(
                                        Capsule()
                                            .fill(filterGradient)
                                            .opacity(isSelected ? 1 : 0)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? Color.clear : PricesTheme.chipBorder,
                                                lineWidth: 1)
                                    )
                            )
                            .foregroundColor(
                                isSelected ? PricesTheme.textPrimary : PricesTheme.textSecondary
                            )
                            .shadow(
                                color: (isSelected ? PricesTheme.accentPrimary : Color.black)
                                    .opacity(isSelected ? 0.45 : 0.25),
                                radius: isSelected ? 10 : 6,
                                x: 0,
                                y: 4
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    fileprivate var sortSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sort")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PricesTheme.textPrimary)
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Last updated: \(lastUpdated, style: .time)")
                        .font(.caption)
                        .foregroundColor(PricesTheme.textSecondary)
                }
            }
            Spacer()
            Menu {
                ForEach(PricesViewModel.SortOption.allCases, id: \.self) { option in
                    Button(option.title) {
                        viewModel.sortOption = option
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.callout)
                    Text(viewModel.sortOption.title)
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(PricesTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(PricesTheme.controlBackground)
                        .overlay(
                            Capsule()
                                .stroke(PricesTheme.border, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    fileprivate var contentSection: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredRows.isEmpty {
                emptyView
            } else {
                LazyVStack(spacing: 12, pinnedViews: []) {
                    ForEach(viewModel.filteredRows) { row in
                        rowView(for: row)
                    }
                }
            }
        }
    }

    private func rowView(for row: PricesViewModel.PriceRow) -> some View {
        PriceRowCard(
            row: row,
            isFavorite: viewModel.isFavorite(row.asset),
            onToggleFavorite: { viewModel.toggleFavorite(for: row.asset) }
        )
        .onAppear {
            // Track visible assets for smart subscription
            let provider = row.asset.provider.rawValue
            visibleAssets[row.asset.code] = provider
            scheduleSubscriptionUpdate()
        }
        .onDisappear {
            // Remove from visible assets
            visibleAssets.removeValue(forKey: row.asset.code)
            scheduleSubscriptionUpdate()
        }
    }

    private func scheduleSubscriptionUpdate() {
        // No-op: Price updates now come from backend cron jobs
        // No manual subscription needed
    }

    fileprivate var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: PricesTheme.accentPrimary))
            Text("Updating prices…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PricesTheme.textPrimary)
            Text("This may take a few seconds.")
                .font(.system(size: 13))
                .foregroundColor(PricesTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PricesTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PricesTheme.border, lineWidth: 1)
                )
        )
    }

    fileprivate var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(PricesTheme.textMuted)
            Text("No prices displayed yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PricesTheme.textPrimary)
            Text("Change filters or try refreshing.")
                .font(.system(size: 13))
                .foregroundColor(PricesTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PricesTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PricesTheme.border, lineWidth: 1)
                )
        )
    }

    fileprivate func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(PricesTheme.negative)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(PricesTheme.negative)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PricesTheme.warningBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PricesTheme.negative.opacity(0.4), lineWidth: 1)
                )
        )
    }

    fileprivate var filterOptions: [FilterChipOption] {
        return FilterChipOption.defaults
    }

    fileprivate var filterGradient: LinearGradient {
        PricesTheme.accentGradient
    }
}

private struct FilterChipOption: Identifiable {
    let id = UUID()
    let title: String
    let category: AssetType?
    let isFavorites: Bool

    static let defaults: [FilterChipOption] = [
        .init(title: "All", category: nil, isFavorites: false),
        .init(title: "Favorites", category: nil, isFavorites: true),
        .init(title: "Forex", category: .forex, isFavorites: false),
        .init(title: "Commodities", category: .commodity, isFavorites: false),
        .init(title: "Crypto", category: .crypto, isFavorites: false),
        .init(title: "US Stocks", category: .us_stock, isFavorites: false),
        .init(title: "US ETFs", category: .us_etf, isFavorites: false),
    ]
}

private struct PriceRowCard: View {
    let row: PricesViewModel.PriceRow
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    private let iconColors: [Color] = [
        Color(hex: "#2C3A5F"),
        Color(hex: "#253850"),
        Color(hex: "#1E2F44"),
        Color(hex: "#3A2F54"),
    ]

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(iconColor)
                .overlay(
                    Text(String(row.asset.code.prefix(2)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PricesTheme.textPrimary)
                )
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.asset.code)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PricesTheme.textPrimary)

                Text(categoryDisplayName(for: row.asset))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PricesTheme.textMuted)

                Text(row.asset.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(PricesTheme.textSecondary)
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFavorite ? PricesTheme.accentPrimary : PricesTheme.textMuted)
                    .padding(.trailing, 4)
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.priceText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PricesTheme.textPrimary)
                Text(row.changeText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(row.changeColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PricesTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PricesTheme.border, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 12)
    }

    private var iconColor: Color {
        guard !iconColors.isEmpty else { return Color(hex: "#2C3A5F") }
        let hash = abs(row.asset.code.hashValue)
        return iconColors[hash % iconColors.count]
    }

    private func categoryDisplayName(for asset: AssetDefinition) -> String {
        guard let type = AssetType(rawValue: asset.category.lowercased()) else {
            return asset.category.capitalized
        }

        switch type {
        case .crypto: return "Crypto"
        case .forex: return "Forex"
        case .commodity: return "Commodity"
        case .us_stock: return "US Stock"
        case .us_etf: return "US ETF"
        }
    }
}

extension PricesViewModel.SortOption {
    var title: String {
        switch self {
        case .nameAZ: return "Name (A-Z)"
        case .nameZA: return "Name (Z-A)"
        case .priceDesc: return "Price (High-Low)"
        case .priceAsc: return "Price (Low-High)"
        case .changeDesc: return "Change (High-Low)"
        case .changeAsc: return "Change (Low-High)"
        }
    }
}

extension PricesViewModel.PriceRow {
    fileprivate var priceText: String {
        if let price {
            return price.currencyString(currencyCode: asset.currency, scale: 2)
        }
        return "—"
    }

    fileprivate var changeText: String {
        guard let change24h else { return "—" }
        return String(format: "%+.2f%%", change24h)
    }

    fileprivate var changeColor: Color {
        guard let change24h else { return PricesTheme.textSecondary }
        if change24h > 0 { return PricesTheme.positive }
        if change24h < 0 { return PricesTheme.negative }
        return PricesTheme.textSecondary
    }
}

private struct EmptyToolbarContent: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            EmptyView()
        }
    }
}
