import SwiftUI

// MARK: - Scenario Premium Design System
// Matches WelcomeView, SettingsView, PricesDashboardView, DashboardView design

enum ScenarioDesign {
    // MARK: - Background Gradient Stops
    static let bgStart = Color(hex: "#0B1120")
    static let bgMid1 = Color(hex: "#141A33")
    static let bgMid2 = Color(hex: "#1A1F3D")
    static let bgEnd = Color(hex: "#2A2F5C")

    // MARK: - Accent Colors
    static let accentPurple = Color(hex: "#7C4DFF")
    static let accentCyan = Color(hex: "#4CC9F0")

    // MARK: - Status Colors
    static let positive = Color(hex: "#4EF47A")
    static let negative = Color(hex: "#FF5C5C")
    static let neutral = Color(hex: "#A0A0A0")
    static let warning = Color(hex: "#FFB74D")

    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.55)
    static let textPlaceholder = Color.white.opacity(0.40)

    // MARK: - Gradients
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

    static let positiveGradient = LinearGradient(
        colors: [Color(hex: "#4CAF50"), Color(hex: "#81C784")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let negativeGradient = LinearGradient(
        colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Asset Type Gradients
    static let cryptoGradient = [Color(hex: "#9C27B0"), Color(hex: "#E040FB")]
    static let forexGradient = [Color(hex: "#00BCD4"), Color(hex: "#4DD0E1")]
    static let stockGradient = [Color(hex: "#3F51B5"), Color(hex: "#7986CB")]
    static let etfGradient = [Color(hex: "#00ACC1"), Color(hex: "#7C4DFF")]
    static let commodityGradient = [Color(hex: "#FF9800"), Color(hex: "#FFB74D")]
}

// MARK: - Scenario Glass Card
struct ScenarioGlassCard<Content: View>: View {
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
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 12)
        )
    }
}

// MARK: - Scenario Background View
struct ScenarioBackgroundView: View {
    var body: some View {
        ZStack {
            ScenarioDesign.backgroundGradient

            RadialGradient(
                colors: [ScenarioDesign.accentPurple.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                colors: [ScenarioDesign.accentCyan.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Premium Gradient Button
struct ScenarioGradientButton: View {
    let title: String
    let icon: String?
    let gradient: [Color]
    let action: () -> Void

    init(
        title: String, icon: String? = nil,
        gradient: [Color] = [ScenarioDesign.accentPurple, ScenarioDesign.accentCyan],
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: gradient[0].opacity(0.4), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Input Field
struct ScenarioInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ScenarioDesign.textSecondary)

            TextField(
                "", text: $text,
                prompt: Text(placeholder).foregroundColor(ScenarioDesign.textPlaceholder)
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(ScenarioDesign.textPrimary)
            .keyboardType(keyboardType)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Stepper Navigation
struct ScenarioStepperNav: View {
    let currentStep: Int
    let totalSteps: Int
    let titles: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { index in
                HStack(spacing: 8) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(
                                index <= currentStep
                                    ? ScenarioDesign.accentGradient
                                    : LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.1), Color.white.opacity(0.1),
                                        ], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: 32, height: 32)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(
                                    index == currentStep ? .white : ScenarioDesign.textMuted)
                        }
                    }

                    // Step title
                    if index < totalSteps - 1 {
                        Text(titles[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(
                                index <= currentStep
                                    ? ScenarioDesign.textPrimary : ScenarioDesign.textMuted
                            )
                            .lineLimit(1)

                        // Connector line
                        Rectangle()
                            .fill(
                                index < currentStep
                                    ? ScenarioDesign.accentCyan : Color.white.opacity(0.12)
                            )
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(titles[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(
                                index <= currentStep
                                    ? ScenarioDesign.textPrimary : ScenarioDesign.textMuted
                            )
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Stat Card
struct ScenarioStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let valueColor: Color
    let icon: String

    init(
        title: String, value: String, subtitle: String? = nil,
        valueColor: Color = ScenarioDesign.textPrimary, icon: String = "chart.line.uptrend.xyaxis"
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.valueColor = valueColor
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(ScenarioDesign.accentPurple.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ScenarioDesign.accentCyan)
                }

                Spacer()
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ScenarioDesign.textSecondary)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(valueColor.opacity(0.8))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
    }
}

// MARK: - Frequency Selector
struct ScenarioFrequencySelector: View {
    @Binding var selectedFrequency: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How many times per month would you like to invest?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ScenarioDesign.textSecondary)

            HStack(spacing: 12) {
                ForEach([1, 2, 3], id: \.self) { freq in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFrequency = freq
                        }
                    } label: {
                        Text("\(freq)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(
                                selectedFrequency == freq ? .white : ScenarioDesign.textSecondary
                            )
                            .frame(width: 56, height: 56)
                            .background(
                                Group {
                                    if selectedFrequency == freq {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(ScenarioDesign.accentGradient)
                                            .shadow(
                                                color: ScenarioDesign.accentPurple.opacity(0.4),
                                                radius: 8, x: 0, y: 4)
                                    } else {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                RoundedRectangle(
                                                    cornerRadius: 16, style: .continuous
                                                )
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Day Picker Field
struct ScenarioDayPicker: View {
    let label: String
    @Binding var day: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ScenarioDesign.textSecondary)

            Spacer()

            Picker("", selection: $day) {
                ForEach(1...28, id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            .pickerStyle(.menu)
            .tint(ScenarioDesign.accentCyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Allocation Row
struct ScenarioAllocationRow: View {
    let assetName: String
    let percentage: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Asset Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: ScenarioDesign.cryptoGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Text(String(assetName.prefix(2)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(assetName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ScenarioDesign.textPrimary)

            Spacer()

            Text(percentage)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ScenarioDesign.accentCyan)

            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ScenarioDesign.negative.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        ScenarioBackgroundView()

        ScrollView {
            VStack(spacing: 20) {
                ScenarioStepperNav(
                    currentStep: 1, totalSteps: 3, titles: ["Date", "Amount", "Allocation"])

                ScenarioGlassCard {
                    ScenarioFrequencySelector(selectedFrequency: .constant(2))
                }

                HStack(spacing: 12) {
                    ScenarioStatCard(
                        title: "Toplam Yatırım", value: "$120,000", icon: "dollarsign.circle.fill")
                    ScenarioStatCard(
                        title: "ROI", value: "+32.5%", subtitle: "+$39,000",
                        valueColor: ScenarioDesign.positive, icon: "arrow.up.right")
                }

                ScenarioGradientButton(title: "Simülasyonu Başlat", icon: "play.fill") {}
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}
