import SwiftUI

/// DCA Simülasyon özet kartları
/// 2x2 grid layout ile temel metrikleri gösterir
public struct SummaryCardsView: View {
    let result: SimulationResult

    public init(result: SimulationResult) {
        self.result = result
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Simulation Summary")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12
            ) {
                // Total Investment
                SummaryCard(
                    title: "Total Investment",
                    value: result.investedTotalFormatted,
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )

                // Current Value
                SummaryCard(
                    title: "Current Value",
                    value: result.currentValueFormatted,
                    icon: "chart.bar.fill",
                    color: .green
                )

                // Profit/Loss (TRY)
                SummaryCard(
                    title: "Profit/Loss",
                    value: result.profitTRYFormatted,
                    icon: result.isProfit ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    color: result.isProfit ? .green : (result.isLoss ? .red : .gray)
                )

                // Profit/Loss (%)
                SummaryCard(
                    title: "Return %",
                    value: result.profitPctFormatted,
                    icon: result.isProfit ? "percent" : "minus.percent",
                    color: result.isProfit ? .green : (result.isLoss ? .red : .gray)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview
struct SummaryCardsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockResult = SimulationResult(
            investedTotalTRY: 240000,
            currentValueTRY: 300000,
            profitTRY: 60000,
            profitPct: 25.0,
            deals: [],
            breakdown: []
        )

        SummaryCardsView(result: mockResult)
            .padding()
    }
}
