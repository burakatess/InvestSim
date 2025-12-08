import SwiftUI

// MARK: - Dashboard Summary Card
struct DashboardSummaryCard: View {
    let summary: AssetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Portfolio Summary")
                .font(.title2)

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(MoneyFormatter.formatUSD(summary.currentValue))
                        .font(.title2.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("ROI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(MoneyFormatter.formatPercentage(summary.profitLossPercentage))")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(summary.profitLoss >= 0 ? .green : .red)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(MoneyFormatter.formatUSD(summary.totalCost))
                        .font(.body)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("P/L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(MoneyFormatter.formatUSD(summary.pnl))
                        .font(.body)
                        .foregroundColor(summary.pnl >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
    }
}

// MARK: - Allocation Pie Chart
struct AllocationPieChartView: View {
    let slices: [AllocationSlice]

    var body: some View {
        VStack(spacing: 16) {
            if slices.isEmpty {
                Text("No allocation data").font(.body).foregroundColor(.secondary).padding()
            } else {
                // Donut chart (rough)
                ZStack {
                    Circle().stroke(Color.borderLight, lineWidth: 18)
                    // segments overlay approximation
                    ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                        Circle()
                            .trim(from: startAngle(idx), to: endAngle(idx))
                            .stroke(colorForAsset(slice.asset), lineWidth: 18)
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 4) {
                        Text("Toplam").font(.caption).foregroundColor(.secondary)
                        Text(totalFormatted()).font(.headline)
                    }
                }
                .frame(height: 160)

                // Legend
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices) { slice in
                        HStack(spacing: 8) {
                            Circle().fill(colorForAsset(slice.asset)).frame(width: 10, height: 10)
                            Text(slice.asset.rawValue).font(.subheadline)
                            Spacer()
                            Text(verbatim: legendLine(for: slice))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
    }

    private func colorForAsset(_ asset: AssetCode) -> Color {
        // Basit renk atama - tüm varlıklar için
        let colors: [Color] = [
            Color(hex: "#2563EB"),
            Color(hex: "#16A34A"),
            Color(hex: "#7C3AED"),
            Color(hex: "#DC2626"),
            Color(hex: "#F97316"),
            Color(hex: "#FACC15"),
            Color(hex: "#EC4899"),
            Color(hex: "#06B6D4"),
            Color(hex: "#A5F3FC"),
            Color(hex: "#4338CA"),
        ]
        let index = abs(asset.rawValue.hashValue) % colors.count
        return colors[index]
    }
    private func startAngle(_ index: Int) -> CGFloat {
        let cum = slices.prefix(index).reduce(0.0) { $0 + $1.percentage }
        return CGFloat(cum)
    }
    private func endAngle(_ index: Int) -> CGFloat {
        let cum = slices.prefix(index + 1).reduce(0.0) { $0 + $1.percentage }
        return CGFloat(cum)
    }
    private func totalFormatted() -> String {
        let total = slices.reduce(Decimal(0)) { $0 + $1.value }
        return MoneyFormatter.formatUSD(total)
    }
    private func legendLine(for slice: AllocationSlice) -> String {
        let percentage = String(format: "%.1f", slice.percentage * 100)
        let valueText = MoneyFormatter.formatUSD(slice.value)
        return "\(percentage)%  •  \(valueText)"
    }
}

// MARK: - Portfolio Line Chart
struct PortfolioLineChartView: View {
    let data: PriceSeries

    var body: some View {
        VStack {
            if data.points.isEmpty {
                Text("No price data")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Simple line representation
                HStack {
                    ForEach(data.points.prefix(10)) { point in
                        VStack {
                            Text("$\(point.priceTRY)")
                                .font(.caption)
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .padding()
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
    }
}
