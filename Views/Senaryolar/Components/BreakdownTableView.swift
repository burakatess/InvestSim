import Combine
import SwiftUI

/// DCA Simülasyon varlık breakdown tablosu
/// Her varlığın detaylı bilgilerini gösterir
public struct BreakdownTableView: View {
    public enum ViewStyle { case table, card }

    let breakdown: [BreakdownRow]
    let style: ViewStyle
    @State private var sortOrder: SortOrder = .symbol
    @State private var ascending = true

    public init(breakdown: [BreakdownRow], style: ViewStyle = .table) {
        self.breakdown = breakdown
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Asset Breakdown")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: {
                            if sortOrder == order {
                                ascending.toggle()
                            } else {
                                sortOrder = order
                                ascending = true
                            }
                        }) {
                            HStack {
                                Text(order.title)
                                if sortOrder == order {
                                    Image(systemName: ascending ? "arrow.up" : "arrow.down")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.title3)
                }
            }

            if style == .table {
                LazyVStack(spacing: 0) {
                    headerRow
                    ForEach(sortedBreakdown) { row in
                        BreakdownRowView(row: row)
                            .background(Rectangle().fill(Color(.systemBackground)))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            } else {
                // Card style
                LazyVStack(spacing: 12) {
                    ForEach(sortedBreakdown) { row in
                        BreakdownCard(row: row, share: portfolioShare(for: row))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("Asset")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Units")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            Text("Avg. Cost")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text("Current Price")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text("Value")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text("P/L %")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }

    // MARK: - Computed Properties

    private var sortedBreakdown: [BreakdownRow] {
        let sorted = breakdown.sorted { (first: BreakdownRow, second: BreakdownRow) in
            let comparison: ComparisonResult

            switch sortOrder {
            case .symbol:
                comparison = first.symbol.compare(second.symbol)
            case .units:
                comparison =
                    first.totalUnits < second.totalUnits
                    ? .orderedAscending
                    : (first.totalUnits > second.totalUnits ? .orderedDescending : .orderedSame)
            case .avgCost:
                comparison =
                    first.avgCostTRY < second.avgCostTRY
                    ? .orderedAscending
                    : (first.avgCostTRY > second.avgCostTRY ? .orderedDescending : .orderedSame)
            case .currentPrice:
                comparison =
                    first.currentPrice < second.currentPrice
                    ? .orderedAscending
                    : (first.currentPrice > second.currentPrice ? .orderedDescending : .orderedSame)
            case .currentValue:
                comparison =
                    first.currentValueTRY < second.currentValueTRY
                    ? .orderedAscending
                    : (first.currentValueTRY > second.currentValueTRY
                        ? .orderedDescending : .orderedSame)
            case .pnl:
                comparison =
                    first.pnlTRY < second.pnlTRY
                    ? .orderedAscending
                    : (first.pnlTRY > second.pnlTRY ? .orderedDescending : .orderedSame)
            case .pnlPct:
                comparison =
                    first.pnlPct < second.pnlPct
                    ? .orderedAscending
                    : (first.pnlPct > second.pnlPct ? .orderedDescending : .orderedSame)
            }

            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        return sorted
    }

    private var totalCurrentValue: Decimal {
        breakdown.reduce(0) { $0 + $1.currentValueTRY }
    }

    private func portfolioShare(for row: BreakdownRow) -> Double {
        guard totalCurrentValue > 0 else { return 0 }
        let ratio = row.currentValueTRY / totalCurrentValue
        return ratio.doubleValue
    }
}

// MARK: - Breakdown Row View
struct BreakdownRowView: View {
    let row: BreakdownRow

    var body: some View {
        HStack {
            // Asset
            Text(row.symbol)
                .font(.body)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Units
            Text(row.totalUnits.rounded(scale: 4).description)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            // Ortalama Maliyet
            Text(row.avgCostTRY.currencyString(scale: 2))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            // Current Price
            Text(row.currentPrice.currencyString(scale: 2))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            // Value
            Text(row.currentValueFormatted)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .trailing)

            // K/Z %
            Text(row.pnlPctFormatted)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(pnlColor)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.clear)
        )
    }

    private var pnlColor: Color {
        if row.isProfit {
            return .green
        } else if row.isLoss {
            return .red
        } else {
            return .gray
        }
    }
}

// MARK: - Card Row
private struct BreakdownCard: View {
    let row: BreakdownRow
    let share: Double
    var body: some View {
        ModernCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    // Logo (varsa) ya da fallback harf
                    let code = AssetCode(row.symbol.replacingOccurrences(of: ".IS", with: ""))
                    BreakdownAsyncImage(
                        urlString: AssetCatalog.shared.metadata(for: code).logoURL,
                        fallbackText: String(row.symbol.prefix(1))
                    )
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
                    Text(row.symbol)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(row.currentValueFormatted)
                            .font(.subheadline)
                            .monospacedDigits()
                        HStack(spacing: 6) {
                            Text(row.pnlPctFormatted)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(
                                    row.isProfit ? .green : (row.isLoss ? .red : .gray))
                            Text((row.pnlTRY).currencyString(scale: 0))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigits()
                        }
                    }
                }
                // Portföy payı
                HStack(spacing: 8) {
                    progressView(for: share)
                    Text(String(format: "%%%0.1f", share * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Label(row.totalUnits.rounded(scale: 4).description, systemImage: "number")
                        .font(.caption).foregroundColor(.secondary)
                    Label(
                        "Avg. \(row.avgCostTRY.currencyString(scale: 2))",
                        systemImage: "wallet.pass"
                    )
                    .font(.caption).foregroundColor(.secondary)
                    Label(
                        "Price \(row.currentPrice.currencyString(scale: 2))",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                    .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func progressView(for value: Double) -> some View {
        if #available(iOS 15.0, *) {
            ProgressView(value: min(1, max(0, value)))
                .progressViewStyle(.linear)
                .tint(Color.blue)
        } else {
            ProgressView(value: min(1, max(0, value)))
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(Color.blue)
        }
    }
}

private struct BreakdownAsyncImage: View {
    let urlString: String?
    let fallbackText: String

    var body: some View {
        if #available(iOS 15.0, *) {
            AsyncImage(url: URL(string: urlString ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackView
            }
        } else {
            LegacyBreakdownAsyncImage(url: URL(string: urlString ?? "")) {
                fallbackView
            }
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        Circle()
            .fill(Color.blue)
            .overlay(
                Text(fallbackText)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
}

private struct LegacyBreakdownAsyncImage<Placeholder: View>: View {
    @StateObject private var loader = BreakdownImageLoader()
    let url: URL?
    let placeholder: () -> Placeholder

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .onAppear { loader.load(from: url) }
    }
}

private final class BreakdownImageLoader: ObservableObject {
    @Published var image: UIImage?

    func load(from url: URL?) {
        guard let url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let image = UIImage(data: data) {
                DispatchQueue.main.async { self.image = image }
            }
        }.resume()
    }
}

extension View {
    @ViewBuilder
    fileprivate func monospacedDigits() -> some View {
        if #available(iOS 15.0, *) {
            self.monospacedDigit()
        } else {
            self
        }
    }
}

// MARK: - Sort Order
enum SortOrder: CaseIterable {
    case symbol
    case units
    case avgCost
    case currentPrice
    case currentValue
    case pnl
    case pnlPct

    var title: String {
        switch self {
        case .symbol: return "Asset"
        case .units: return "Units"
        case .avgCost: return "Avg. Cost"
        case .currentPrice: return "Current Price"
        case .currentValue: return "Value"
        case .pnl: return "P/L ($)"
        case .pnlPct: return "P/L (%)"
        }
    }
}

// MARK: - Preview
struct BreakdownTableView_Previews: PreviewProvider {
    static var previews: some View {
        let mockBreakdown = [
            BreakdownRow.create(
                symbol: "BTCTRY",
                totalUnits: 0.5,
                avgCostTRY: 400000,
                currentPrice: 800000
            ),
            BreakdownRow.create(
                symbol: "XAUTRY",
                totalUnits: 10,
                avgCostTRY: 2000,
                currentPrice: 2500
            ),
        ]

        BreakdownTableView(breakdown: mockBreakdown)
            .padding()
    }
}
