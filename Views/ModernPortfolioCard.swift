import Charts
import SwiftUI

struct ModernPortfolioCard: View {
    let totalValue: Double
    let totalGain: Double
    let totalGainPercentage: Double
    let volatility: Double
    let isDarkMode: Bool

    @State private var animatedValue: Double = 0
    @State private var animatedGain: Double = 0
    @State private var animatedPercentage: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Main Value Section
            VStack(spacing: 12) {
                // Title
                HStack {
                    Text("Total Portfolio Value")
                        .font(.titleMedium)
                        .foregroundColor(isDarkMode ? .white : .textPrimary)

                    Spacer()

                    // Status Indicator
                    HStack(spacing: 4) {
                        Image(systemName: totalGain >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(totalGain >= 0 ? Color.success : Color.error)

                        Text("\(animatedPercentage, specifier: "%.1f")%")
                            .font(.percentageSmall)
                            .foregroundColor(totalGain >= 0 ? Color.success : Color.error)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((totalGain >= 0 ? Color.success : Color.error).opacity(0.1))
                    )
                }

                // Main Value
                Text(formattedAnimatedValue)
                    .font(.moneyLarge)
                    .foregroundColor(isDarkMode ? .white : .textPrimary)
                    .numericTextTransition()

                // Gain/Loss
                HStack(spacing: 8) {
                    Text(formattedAnimatedGain)
                        .font(.moneyMedium)
                        .foregroundColor(totalGain >= 0 ? Color.success : Color.error)

                    Text("(\(animatedPercentage, specifier: "%.1f")%)")
                        .font(.percentageMedium)
                        .foregroundColor(totalGain >= 0 ? Color.success : Color.error)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isDarkMode
                            ? LinearGradient(
                                colors: [Color(hex: "#1F2937"), Color(hex: "#111827")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) : Color.gradientBlue
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isDarkMode ? Color.borderDark : Color.borderLight,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isDarkMode ? .black.opacity(0.3) : .primaryBlue.opacity(0.1),
                radius: 12,
                x: 0,
                y: 4
            )

            // Mini Sparkline Chart
            if totalValue > 0 {
                MiniSparklineChart(
                    data: generateMockSparklineData(),
                    isPositive: totalGain >= 0,
                    isDarkMode: isDarkMode
                )
                .frame(height: 40)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            animateValues()
        }
        .onChange(of: totalValue) { _, _ in
            animateValues()
        }
    }

    private func animateValues() {
        withAnimation(.easeOut(duration: 1.0)) {
            animatedValue = totalValue
        }

        withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
            animatedGain = totalGain
        }

        withAnimation(.easeOut(duration: 1.4).delay(0.4)) {
            animatedPercentage = totalGainPercentage
        }
    }

    private func generateMockSparklineData() -> [Double] {
        // Generate mock sparkline data
        let baseValue = totalValue
        let variation = baseValue * 0.05  // 5% variation
        return (0..<20).map { _ in
            baseValue + Double.random(in: -variation...variation)
        }
    }

    private var formattedAnimatedValue: String {
        MoneyFormatter.formatTRY(Decimal(max(animatedValue, 0)))
    }

    private var formattedAnimatedGain: String {
        let amount = MoneyFormatter.formatTRY(Decimal(abs(animatedGain)))
        if animatedGain > 0 {
            return "+\(amount)"
        } else if animatedGain < 0 {
            return "-\(amount)"
        } else {
            return amount
        }
    }
}

struct MiniSparklineChart: View {
    let data: [Double]
    let isPositive: Bool
    let isDarkMode: Bool

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: isPositive
                                    ? [Color.success, Color.successLight]
                                    : [Color.error, Color.errorLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                .chartYScale(domain: data.min()!...data.max()!)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            } else {
                LegacySparkline(
                    data: data,
                    lineColor: isPositive ? Color.success : Color.error
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isDarkMode
                        ? Color.black.opacity(0.2)
                        : (isPositive ? Color.success : Color.error).opacity(0.05)
                )
        )
    }
}

private struct LegacySparkline: View {
    let data: [Double]
    let lineColor: Color

    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(in: geometry.size)
            Path { path in
                guard let firstPoint = points.first else { return }
                path.move(to: firstPoint)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard let minValue = data.min(), let maxValue = data.max(), size.width > 0 else {
            return []
        }
        let range = max(maxValue - minValue, .leastNonzeroMagnitude)
        let count = max(data.count - 1, 1)
        return data.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(count)
            let yNormalized = (value - minValue) / range
            let y = size.height * (1 - CGFloat(yNormalized))
            return CGPoint(x: x, y: y)
        }
    }
}

extension View {
    @ViewBuilder
    fileprivate func numericTextTransition() -> some View {
        if #available(iOS 16.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ModernPortfolioCard(
            totalValue: 125000.50,
            totalGain: 2500.75,
            totalGainPercentage: 2.04,
            volatility: 12.5,
            isDarkMode: false
        )

        ModernPortfolioCard(
            totalValue: 125000.50,
            totalGain: -1500.25,
            totalGainPercentage: -1.2,
            volatility: 12.5,
            isDarkMode: true
        )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
