import SwiftUI

/// DCA Simülasyon deal log listesi
/// Tüm işlemleri tarih sırasına göre gösterir
public struct DealLogListView: View {
    let deals: [DealLog]
    @State private var selectedFilter: FilterType = .all
    @State private var searchText = ""
    @State private var grouping: Grouping = .byMonth

    public init(deals: [DealLog]) {
        self.deals = deals
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transaction History")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(filteredDeals.count) transactions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Filter buttons
            filterButtons

            // Search bar
            searchBar

            // Group selector
            Picker("Grouping", selection: $grouping) {
                ForEach(Grouping.allCases, id: \.self) { g in
                    Text(g.title).tag(g)
                }
            }
            .pickerStyle(.segmented)

            // Deal list (grouped)
            LazyVStack(spacing: 12) {
                ForEach(groupedKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(key)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        LazyVStack(spacing: 0) {
                            ForEach(groupedDeals[key] ?? []) { deal in
                                DealLogRowView(deal: deal)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25))
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Subviews

    private var filterButtons: some View {
        HStack(spacing: 8) {
            ForEach(FilterType.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    Text(filter.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedFilter == filter ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    selectedFilter == filter ? Color.blue : Color.blue.opacity(0.1))
                        )
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search assets...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Computed Properties

    private var filteredDeals: [DealLog] {
        var filtered = deals

        // Filter by type
        switch selectedFilter {
        case .all:
            break
        case .successful:
            filtered = filtered.filter { $0.isSuccessful }
        case .skipped:
            filtered = filtered.filter { $0.skipped }
        }

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { deal in
                deal.symbol.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by date (newest first)
        return filtered.sorted { $0.date > $1.date }
    }

    private var groupedDeals: [String: [DealLog]] {
        switch grouping {
        case .byMonth:
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL yyyy"
            formatter.locale = Locale(identifier: "en_US")
            return Dictionary(grouping: filteredDeals) { formatter.string(from: $0.date) }
        case .byQuarter:
            let calendar = Calendar.current
            return Dictionary(grouping: filteredDeals) { deal in
                let comps = calendar.dateComponents([.year, .month], from: deal.date)
                let q = ((comps.month ?? 1) - 1) / 3 + 1
                return "Q\(q) \(comps.year ?? 0)"
            }
        case .byYear:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return Dictionary(grouping: filteredDeals) { formatter.string(from: $0.date) }
        case .byAsset:
            return Dictionary(grouping: filteredDeals) { $0.symbol }
        }
    }

    private var groupedKeys: [String] {
        groupedDeals.keys.sorted { $0 < $1 }
    }
}

// MARK: - Deal Log Row View
struct DealLogRowView: View {
    let deal: DealLog

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(deal.symbol)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    Text(deal.date.ddMMyyyyString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if deal.skipped {
                    Text("Price not found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    HStack {
                        Text("\(deal.units.rounded(scale: 6)) units")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("@ \(deal.price.currencyString(scale: 2))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Spent: \(deal.spentTRY.currencyString())")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if deal.daysDifference != 0 {
                            Text("\(deal.daysDifference > 0 ? "+" : "")\(deal.daysDifference) days")
                                .font(.caption)
                                .foregroundColor(deal.daysDifference > 0 ? .orange : .blue)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(deal.skipped ? Color.gray.opacity(0.1) : Color.clear)
        )
    }

    private var statusIcon: some View {
        Image(systemName: deal.skipped ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .font(.title3)
            .foregroundColor(deal.skipped ? .orange : .green)
    }
}

// MARK: - Filter Type
enum FilterType: CaseIterable {
    case all
    case successful
    case skipped

    var title: String {
        switch self {
        case .all: return "All"
        case .successful: return "Successful"
        case .skipped: return "Skipped"
        }
    }
}

enum Grouping: CaseIterable {
    case byMonth, byQuarter, byYear, byAsset
    var title: String {
        switch self {
        case .byMonth: return "Monthly"
        case .byQuarter: return "Quarterly"
        case .byYear: return "Yearly"
        case .byAsset: return "Asset"
        }
    }
}

// MARK: - Preview
struct DealLogListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockDeals = [
            DealLog.successful(
                date: Date(),
                targetDate: Date(),
                symbol: "BTCTRY",
                price: 300000,
                units: 0.1,
                spentTRY: 30000
            ),
            DealLog.skipped(
                targetDate: Date(),
                symbol: "ETHTRY"
            ),
        ]

        DealLogListView(deals: mockDeals)
            .padding()
    }
}
