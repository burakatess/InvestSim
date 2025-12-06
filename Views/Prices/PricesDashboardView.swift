import SwiftUI

// MARK: - Prices Design System
private enum PricesDesign {
    // Background gradient stops
    static let bgStart = Color(hex: "#0B1120")
    static let bgMid1 = Color(hex: "#141A33")
    static let bgMid2 = Color(hex: "#1A1F3D")
    static let bgEnd = Color(hex: "#2A2F5C")

    // Accent colors
    static let accentPurple = Color(hex: "#7C4DFF")
    static let accentCyan = Color(hex: "#4CC9F0")

    // Status colors
    static let positive = Color(hex: "#4EF47A")
    static let negative = Color(hex: "#FF5C5C")
    static let neutral = Color(hex: "#A0A0A0")

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.55)
    static let textPlaceholder = Color.white.opacity(0.40)

    // Gradients
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

    // Icon gradient colors for variety
    static let iconGradients: [[Color]] = [
        [Color(hex: "#7C4DFF"), Color(hex: "#B47CFF")],
        [Color(hex: "#4CC9F0"), Color(hex: "#00D9FF")],
        [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
        [Color(hex: "#4CAF50"), Color(hex: "#81C784")],
        [Color(hex: "#FF9800"), Color(hex: "#FFB74D")],
        [Color(hex: "#E040FB"), Color(hex: "#EA80FC")],
    ]
}

// MARK: - Glass Icon Circle
private struct GlassIconCircle: View {
    let symbol: String
    let colors: [Color]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: colors.first?.opacity(0.4) ?? .clear, radius: 8, x: 0, y: 4)

            Text(String(symbol.prefix(2)).uppercased())
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Filter Tab Button (NO DragGesture - fixes scroll)
private struct FilterTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : PricesDesign.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(PricesDesign.accentGradient)
                                .shadow(
                                    color: PricesDesign.accentPurple.opacity(0.5), radius: 12, x: 0,
                                    y: 4)
                        } else {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Search Bar
private struct PremiumSearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? PricesDesign.accentCyan : PricesDesign.textMuted)

            TextField(
                "", text: $text,
                prompt: Text("Search assets (BTC, gold, stock…)").foregroundColor(
                    PricesDesign.textPlaceholder)
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(PricesDesign.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(PricesDesign.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isFocused
                                ? PricesDesign.accentCyan.opacity(0.5) : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

// MARK: - Premium Asset Row (NO DragGesture - fixes scroll)
private struct PremiumAssetRow: View {
    let row: PricesViewModel.PriceRow
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    private var iconColors: [Color] {
        let index = abs(row.asset.code.hashValue) % PricesDesign.iconGradients.count
        return PricesDesign.iconGradients[index]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            GlassIconCircle(symbol: row.asset.code, colors: iconColors)

            // Asset Info
            VStack(alignment: .leading, spacing: 3) {
                Text(row.asset.code)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PricesDesign.textPrimary)

                Text(categoryBadge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PricesDesign.accentCyan)

                Text(row.asset.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PricesDesign.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Favorite Button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isFavorite ? Color(hex: "#FFD700") : PricesDesign.textMuted)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            // Price + Change
            VStack(alignment: .trailing, spacing: 4) {
                Text(priceText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PricesDesign.textPrimary)

                Text(changeText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(changeColor.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        )
    }

    private var categoryBadge: String {
        guard let type = AssetType(rawValue: row.asset.category.lowercased()) else {
            return row.asset.category.uppercased()
        }
        switch type {
        case .crypto: return "CRYPTO"
        case .forex: return "FOREX"
        case .commodity: return "COMMODITY"
        case .us_stock: return "US STOCK"
        case .us_etf: return "US ETF"
        }
    }

    private var priceText: String {
        if let price = row.price {
            return price.currencyString(currencyCode: row.asset.currency, scale: 2)
        }
        return "—"
    }

    private var changeText: String {
        guard let change = row.change24h else { return "—" }
        return String(format: "%+.2f%%", change)
    }

    private var changeColor: Color {
        guard let change = row.change24h else { return PricesDesign.neutral }
        if change > 0 { return PricesDesign.positive }
        if change < 0 { return PricesDesign.negative }
        return PricesDesign.neutral
    }
}

// MARK: - Empty State View
private struct PremiumEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(PricesDesign.accentPurple.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(PricesDesign.accentCyan)
            }

            VStack(spacing: 8) {
                Text("No prices displayed yet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(PricesDesign.textPrimary)

                Text("Change filters or try refreshing.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PricesDesign.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 12)
        )
    }
}

// MARK: - Loading View
private struct PremiumLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: PricesDesign.accentCyan))
                .scaleEffect(1.2)

            Text("Updating prices…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PricesDesign.textPrimary)

            Text("This may take a few seconds.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(PricesDesign.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 12)
        )
    }
}

// MARK: - Filter Options
private struct FilterOption: Identifiable {
    let id = UUID()
    let title: String
    let category: AssetType?
    let isFavorites: Bool

    static let all: [FilterOption] = [
        .init(title: "All", category: nil, isFavorites: false),
        .init(title: "Favorites", category: nil, isFavorites: true),
        .init(title: "Forex", category: .forex, isFavorites: false),
        .init(title: "Crypto", category: .crypto, isFavorites: false),
        .init(title: "US Stocks", category: .us_stock, isFavorites: false),
        .init(title: "US ETFs", category: .us_etf, isFavorites: false),
        .init(title: "Commodities", category: .commodity, isFavorites: false),
    ]
}

// MARK: - Prices Dashboard View (Premium Fintech Design)
struct PricesDashboardView: View {
    @StateObject private var viewModel: PricesViewModel
    @State private var hasAppeared = false
    @State private var priceRefreshTimer: Timer?
    @State private var isAppearing = false
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

    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            PricesDesign.backgroundGradient

            // Subtle radial glows
            RadialGradient(
                colors: [PricesDesign.accentPurple.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                colors: [PricesDesign.accentCyan.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prices")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(PricesDesign.textPrimary)

                Text("View real-time market data")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(PricesDesign.textSecondary)
            }

            Spacer()

            if let lastUpdated = viewModel.lastUpdated {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Updated")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(PricesDesign.textMuted)

                    Text(lastUpdated, style: .time)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(PricesDesign.accentCyan)
                }
            }
        }
    }

    // MARK: - Filter Section (HORIZONTAL SCROLL - FIXED)
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterOption.all) { option in
                    let isSelected: Bool = {
                        if option.isFavorites { return viewModel.showFavoritesOnly }
                        if let category = option.category {
                            return !viewModel.showFavoritesOnly
                                && viewModel.selectedCategory == category
                        }
                        return !viewModel.showFavoritesOnly && viewModel.selectedCategory == nil
                    }()

                    FilterTabButton(
                        title: option.title,
                        isSelected: isSelected
                    ) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            if option.isFavorites {
                                viewModel.showFavoritesOnly = true
                                viewModel.selectedCategory = nil
                            } else {
                                viewModel.showFavoritesOnly = false
                                viewModel.selectedCategory = option.category
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Sort Section
    private var sortSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sort")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PricesDesign.textPrimary)

                if let lastUpdated = viewModel.lastUpdated {
                    Text("Last updated: \(lastUpdated, style: .time)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PricesDesign.textMuted)
                }
            }

            Spacer()

            Menu {
                ForEach(PricesViewModel.SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.sortOption = option
                        }
                    } label: {
                        HStack {
                            Text(option.title)
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 16, weight: .medium))

                    Text(viewModel.sortOption.title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(PricesDesign.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.25))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(PricesDesign.negative)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PricesDesign.negative)
                .lineLimit(2)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PricesDesign.negative.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PricesDesign.negative.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Asset List Content
    @ViewBuilder
    private var assetListContent: some View {
        if viewModel.isLoading {
            PremiumLoadingView()
                .padding(.horizontal, 20)
        } else if viewModel.filteredRows.isEmpty {
            PremiumEmptyState()
                .padding(.horizontal, 20)
        } else {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.filteredRows) { row in
                    PremiumAssetRow(
                        row: row,
                        isFavorite: viewModel.isFavorite(row.asset),
                        onToggleFavorite: { viewModel.toggleFavorite(for: row.asset) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Body (SINGLE SCROLLVIEW - SIMPLIFIED)
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                // Single ScrollView for everything
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        headerSection
                            .padding(.horizontal, 20)
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)

                        // Search Bar
                        PremiumSearchBar(text: $viewModel.searchText)
                            .padding(.horizontal, 20)
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)

                        // Filter Tabs (Horizontal Scroll)
                        filterSection
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)

                        // Sort Section
                        sortSection
                            .padding(.horizontal, 20)
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)

                        // Error Banner
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                                .padding(.horizontal, 20)
                        }

                        // Asset List
                        assetListContent
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .onAppear {
                // Entrance animation
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                    isAppearing = true
                }

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

// MARK: - Sort Option Title
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

// MARK: - Preview
#Preview {
    PricesDashboardView()
        .preferredColorScheme(.dark)
}
