import Charts
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Scenario Result View (Full Implementation)
struct ScenarioResultView: View {
    let cardData: ScenarioCardData
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [ScenarioTransaction] = []
    @State private var expandedMonths: Set<String> = []
    @State private var selectedChartType: ChartType = .portfolio
    @State private var showExportMenu = false
    @State private var showFilterSheet = false
    @State private var filterAsset: String? = nil
    @State private var isAppearing = false

    enum ChartType: String, CaseIterable {
        case portfolio = "Portföy"
        case monthly = "Aylık"
        case allocation = "Dağılım"
    }

    // Grouped transactions by month
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

    // Unique assets
    private var uniqueAssets: [String] {
        Array(Set(transactions.map { $0.asset })).sorted()
    }

    // Filtered transactions
    private var filteredTransactions: [ScenarioTransaction] {
        if let filterAsset {
            return transactions.filter { $0.asset == filterAsset }
        }
        return transactions
    }

    // Portfolio value over time (mock)
    private var portfolioData: [(Date, Double)] {
        var data: [(Date, Double)] = []
        var cumulativeValue = 0.0
        let sortedTransactions = transactions.sorted { $0.date < $1.date }

        for transaction in sortedTransactions {
            cumulativeValue +=
                NSDecimalNumber(decimal: transaction.allocatedMoneyUSD).doubleValue * 1.1  // Mock growth
            if data.isEmpty
                || Calendar.current.compare(data.last!.0, to: transaction.date, toGranularity: .day)
                    != .orderedSame
            {
                data.append((transaction.date, cumulativeValue))
            } else {
                data[data.count - 1] = (transaction.date, cumulativeValue)
            }
        }
        return data
    }

    // Monthly investment data
    private var monthlyData: [(String, Double)] {
        var data: [String: Double] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"

        for transaction in transactions {
            let key = formatter.string(from: transaction.date)
            data[key, default: 0] +=
                NSDecimalNumber(decimal: transaction.allocatedMoneyUSD).doubleValue
        }

        return data.sorted { lhs, rhs in
            lhs.key < rhs.key
        }.map { ($0.key, $0.value) }
    }

    // Allocation data
    private var allocationData: [(String, Double, Color)] {
        var totals: [String: Double] = [:]
        let colors: [Color] = [
            ScenarioDesign.accentPurple, ScenarioDesign.accentCyan, ScenarioDesign.positive,
            ScenarioDesign.warning, Color(hex: "#E040FB"),
        ]

        for transaction in transactions {
            totals[transaction.asset, default: 0] +=
                NSDecimalNumber(decimal: transaction.allocatedMoneyUSD).doubleValue
        }

        let total = totals.values.reduce(0, +)
        guard total > 0 else { return [] }

        return totals.sorted { $0.value > $1.value }.enumerated().map { index, item in
            (item.key, (item.value / total) * 100, colors[index % colors.count])
        }
    }

    var body: some View {
        ZStack {
            ScenarioBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Summary Cards
                    summarySection
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)

                    // Charts
                    chartsSection
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)

                    // Transaction History
                    transactionHistorySection
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)

                    // Action Buttons
                    actionButtonsSection
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(cardData.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { /* Edit */  }) {
                        Label("Senaryoyu Düzenle", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { /* Delete */  }) {
                        Label("Senaryoyu Sil", systemImage: "trash")
                    }
                    Divider()
                    Button(action: { exportCSV() }) {
                        Label("CSV İndir", systemImage: "arrow.down.doc")
                    }
                    Button(action: { exportPDF() }) {
                        Label("PDF İndir", systemImage: "arrow.down.doc.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ScenarioDesign.textPrimary)
                }
            }
        }
        .onAppear {
            loadMockTransactions()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            filterSheet
        }
    }

    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ScenarioStatCard(
                    title: "Toplam Yatırım",
                    value:
                        "$\(NSDecimalNumber(decimal: cardData.totalInvestedUSD).intValue.formatted())",
                    icon: "dollarsign.circle.fill"
                )

                ScenarioStatCard(
                    title: "Son Portföy Değeri",
                    value:
                        "$\(NSDecimalNumber(decimal: cardData.finalValueUSD).intValue.formatted())",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }

            let profit = cardData.finalValueUSD - cardData.totalInvestedUSD
            ScenarioStatCard(
                title: "Kâr/Zarar (ROI)",
                value: String(format: "%+.1f%%", cardData.roiPercent),
                subtitle: "$\(NSDecimalNumber(decimal: profit).intValue.formatted())",
                valueColor: cardData.roiPercent >= 0
                    ? ScenarioDesign.positive : ScenarioDesign.negative,
                icon: cardData.roiPercent >= 0 ? "arrow.up.right" : "arrow.down.right"
            )
        }
    }

    // MARK: - Charts Section
    private var chartsSection: some View {
        ScenarioGlassCard(spacing: 20) {
            // Chart Type Selector
            HStack(spacing: 8) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedChartType = type
                        }
                    } label: {
                        Text(type.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(
                                selectedChartType == type ? .white : ScenarioDesign.textSecondary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedChartType == type {
                                        Capsule()
                                            .fill(ScenarioDesign.accentGradient)
                                    } else {
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Chart Content
            Group {
                switch selectedChartType {
                case .portfolio:
                    portfolioChart
                case .monthly:
                    monthlyChart
                case .allocation:
                    allocationChart
                }
            }
            .frame(height: 200)
        }
    }

    // Portfolio Line Chart
    private var portfolioChart: some View {
        Group {
            if portfolioData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(portfolioData, id: \.0) { point in
                        LineMark(
                            x: .value("Tarih", point.0),
                            y: .value("Değer", point.1)
                        )
                        .foregroundStyle(ScenarioDesign.accentGradient)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Tarih", point.0),
                            y: .value("Değer", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    ScenarioDesign.accentPurple.opacity(0.3),
                                    ScenarioDesign.accentCyan.opacity(0.05),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(
                            ScenarioDesign.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatShortCurrency(v))
                                    .foregroundColor(ScenarioDesign.textMuted)
                            }
                        }
                    }
                }
            }
        }
    }

    // Monthly Bar Chart
    private var monthlyChart: some View {
        Group {
            if monthlyData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(monthlyData, id: \.0) { item in
                        BarMark(
                            x: .value("Ay", item.0),
                            y: .value("Tutar", item.1)
                        )
                        .foregroundStyle(ScenarioDesign.accentGradient)
                        .cornerRadius(6)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(ScenarioDesign.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatShortCurrency(v))
                                    .foregroundColor(ScenarioDesign.textMuted)
                            }
                        }
                    }
                }
            }
        }
    }

    // Allocation Pie Chart
    private var allocationChart: some View {
        Group {
            if allocationData.isEmpty {
                emptyChartPlaceholder
            } else {
                HStack(spacing: 24) {
                    Chart(allocationData, id: \.0) { item in
                        SectorMark(
                            angle: .value("Oran", item.1),
                            innerRadius: .ratio(0.6),
                            outerRadius: .ratio(0.95),
                            angularInset: 2
                        )
                        .foregroundStyle(item.2)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(allocationData.prefix(5), id: \.0) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.2)
                                    .frame(width: 10, height: 10)

                                Text(item.0)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ScenarioDesign.textPrimary)

                                Spacer()

                                Text(String(format: "%.1f%%", item.1))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(ScenarioDesign.accentCyan)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(ScenarioDesign.textMuted)
            Text("Veri yok")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ScenarioDesign.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Transaction History Section
    private var transactionHistorySection: some View {
        ScenarioGlassCard(spacing: 16) {
            HStack {
                Text("Aylık Alım Geçmişi")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ScenarioDesign.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Filtre")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(
                            filterAsset != nil
                                ? ScenarioDesign.accentCyan : ScenarioDesign.textSecondary
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    filterAsset != nil
                                        ? ScenarioDesign.accentCyan.opacity(0.15)
                                        : Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        exportCSV()
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ScenarioDesign.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if groupedByMonth.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(ScenarioDesign.textMuted)
                    Text("İşlem bulunamadı")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(groupedByMonth, id: \.0) { month, monthTransactions in
                        CollapsibleMonthSection(
                            month: month,
                            transactions: filterAsset != nil
                                ? monthTransactions.filter { $0.asset == filterAsset }
                                : monthTransactions,
                            isExpanded: expandedMonths.contains(month),
                            onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedMonths.contains(month) {
                                        expandedMonths.remove(month)
                                    } else {
                                        expandedMonths.insert(month)
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            ScenarioGradientButton(title: "Senaryoyu Kaydet", icon: "square.and.arrow.down") {
                // TODO: Save scenario
            }

            HStack(spacing: 12) {
                Button {
                    // Re-simulate
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Tekrar Simüle Et")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ScenarioDesign.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Yeni Senaryo")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ScenarioDesign.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Filter Sheet
    private var filterSheet: some View {
        NavigationView {
            ZStack {
                ScenarioBackgroundView()

                ScrollView {
                    VStack(spacing: 12) {
                        Button {
                            filterAsset = nil
                            showFilterSheet = false
                        } label: {
                            HStack {
                                Text("Tüm Varlıklar")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(ScenarioDesign.textPrimary)
                                Spacer()
                                if filterAsset == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ScenarioDesign.accentCyan)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        filterAsset == nil
                                            ? ScenarioDesign.accentCyan.opacity(0.12)
                                            : Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(uniqueAssets, id: \.self) { asset in
                            Button {
                                filterAsset = asset
                                showFilterSheet = false
                            } label: {
                                HStack {
                                    Text(asset)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ScenarioDesign.textPrimary)
                                    Spacer()
                                    if filterAsset == asset {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(ScenarioDesign.accentCyan)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            filterAsset == asset
                                                ? ScenarioDesign.accentCyan.opacity(0.12)
                                                : Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Varlık Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { showFilterSheet = false }
                        .foregroundColor(ScenarioDesign.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers
    private func loadMockTransactions() {
        // Generate simple mock transactions for preview
        let calendar = Calendar.current
        var mockTransactions: [ScenarioTransaction] = []
        var currentDate = cardData.startDate
        var cumulativeQty: Decimal = 0

        while currentDate <= cardData.endDate {
            let monthlyAmount = cardData.totalInvestedUSD / Decimal(12)
            let mockPrice = NSDecimalNumber(value: Double.random(in: 30000...50000)).decimalValue
            let qty = monthlyAmount / mockPrice
            cumulativeQty += qty

            mockTransactions.append(
                ScenarioTransaction(
                    id: UUID(),
                    date: currentDate,
                    asset: "BTCUSDT",
                    priceUSD: mockPrice,
                    allocatedMoneyUSD: monthlyAmount,
                    quantity: qty,
                    cumulativeQuantity: cumulativeQty
                ))

            currentDate =
                calendar.date(byAdding: .month, value: 1, to: currentDate) ?? cardData.endDate
        }

        transactions = mockTransactions
    }

    private func formatShortCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "$%.1fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    private func exportCSV() {
        // TODO: Implement CSV export
        let csvContent = generateCSV()
        print("CSV Export: \(csvContent.prefix(500))")
    }

    private func exportPDF() {
        // TODO: Implement PDF export
        print("PDF Export triggered")
    }

    private func generateCSV() -> String {
        var csv = "Tarih,Varlık,Fiyat (USD),Tutar (USD),Adet,Kümülatif Adet\n"
        for t in transactions {
            csv +=
                "\(t.formattedDate),\(t.asset),\(t.priceUSD),\(t.allocatedMoneyUSD),\(t.quantity),\(t.cumulativeQuantity)\n"
        }
        return csv
    }
}

// MARK: - Collapsible Month Section
private struct CollapsibleMonthSection: View {
    let month: String
    let transactions: [ScenarioTransaction]
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ScenarioDesign.textMuted)
                        .frame(width: 20)

                    Text(month)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    Text("(\(transactions.count) işlem)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)

                    Spacer()

                    let total = transactions.reduce(Decimal.zero) { $0 + $1.allocatedMoneyUSD }
                    Text("$\(NSDecimalNumber(decimal: total).intValue.formatted())")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ScenarioDesign.accentCyan)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            // Expanded Content
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Transaction Row
private struct TransactionRow: View {
    let transaction: ScenarioTransaction

    var body: some View {
        HStack(spacing: 12) {
            // Asset Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: ScenarioDesign.cryptoGradient, startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)

                Text(String(transaction.asset.prefix(2)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.asset)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    Text(transaction.formattedDate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ScenarioDesign.textMuted)
                }

                Text(
                    "Fiyat: $\(NSDecimalNumber(decimal: transaction.priceUSD).doubleValue.formatted())"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ScenarioDesign.textSecondary)
            }

            Spacer()

            // Amount and Quantity
            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    "$\(NSDecimalNumber(decimal: transaction.allocatedMoneyUSD).intValue.formatted())"
                )
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ScenarioDesign.textPrimary)

                Text(
                    "\(String(format: "%.6f", NSDecimalNumber(decimal: transaction.quantity).doubleValue)) adet"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(ScenarioDesign.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ScenarioResultView(
            cardData: ScenarioCardData(
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
            ))
    }
    .preferredColorScheme(.dark)
}
