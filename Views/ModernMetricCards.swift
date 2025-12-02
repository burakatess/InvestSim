import SwiftUI

struct ModernMetricCards: View {
    let assetCount: Int
    let totalGainPercentage: Double
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Asset Count Card
            MetricCard(
                title: "Varlık",
                value: "\(assetCount)",
                subtitle: "Adet",
                icon: "chart.pie.fill",
                color: .primaryBlue,
                isDarkMode: isDarkMode
            )
            
            // Gain Percentage Card
            MetricCard(
                title: "Getiri",
                value: String(format: "%.1f%%", totalGainPercentage),
                subtitle: totalGainPercentage >= 0 ? "Kazanç" : "Kayıp",
                icon: totalGainPercentage >= 0 ? "arrow.up.right" : "arrow.down.right",
                color: totalGainPercentage >= 0 ? .success : .error,
                isDarkMode: isDarkMode
            )
            
        }
        .padding(.horizontal, 20)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let isDarkMode: Bool
    
    @State private var animatedValue: String = "0"
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            // Value
            Text(animatedValue)
                .font(.moneySmall)
                .foregroundColor(isDarkMode ? .white : .textPrimary)
                .fontWeight(.bold)
                .numericTextTransition()
            
            // Title
            Text(title)
                .font(.labelMedium)
                .foregroundColor(isDarkMode ? .textTertiary : .textSecondary)
            
            // Subtitle
            Text(subtitle)
                .font(.labelSmall)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isDarkMode ? 
                    Color(hex: "#1F2937") : 
                    Color.white
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDarkMode ? Color.borderDark : color.opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(
            color: isDarkMode ? .black.opacity(0.2) : color.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                isVisible = true
            }
            
            // Animate value
            animateValue()
        }
    }
    
    private func animateValue() {
        // Extract numeric value for animation
        let numericValue = Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
        
        if numericValue > 0 {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedValue = value
            }
        } else {
            animatedValue = value
        }
    }
}

private extension View {
    @ViewBuilder
    func numericTextTransition() -> some View {
        if #available(iOS 16.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ModernMetricCards(
            assetCount: 5,
            totalGainPercentage: 12.5,
            isDarkMode: false
        )
        
        ModernMetricCards(
            assetCount: 3,
            totalGainPercentage: -2.1,
            isDarkMode: true
        )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
