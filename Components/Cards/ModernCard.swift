import SwiftUI

struct ModernCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    let action: (() -> Void)?

    init(
        style: CardStyle = .default, action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.action = action
        self.content = content()
    }

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        content
            .padding(style.padding)
            .background(style.backgroundColor)
            .cornerRadius(style.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
            .shadow(style.shadow)
    }
}

struct CardStyle {
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let padding: CGFloat
    let shadow: ShadowStyle

    static let `default` = CardStyle(
        backgroundColor: .adaptiveSecondaryBackground,
        borderColor: .borderLight,
        borderWidth: 1,
        cornerRadius: 12,
        padding: 16,
        shadow: .small
    )

    static let elevated = CardStyle(
        backgroundColor: .adaptiveSecondaryBackground,
        borderColor: .clear,
        borderWidth: 0,
        cornerRadius: 16,
        padding: 20,
        shadow: .medium
    )

    static let outlined = CardStyle(
        backgroundColor: .clear,
        borderColor: .borderMedium,
        borderWidth: 1,
        cornerRadius: 12,
        padding: 16,
        shadow: .none
    )

    static let filled = CardStyle(
        backgroundColor: .primaryBlue.opacity(0.1),
        borderColor: .primaryBlue.opacity(0.3),
        borderWidth: 1,
        cornerRadius: 12,
        padding: 16,
        shadow: .small
    )
}

// Specialized Card Types
struct InfoCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let value: String
    let change: String?
    let changeType: ChangeType

    enum ChangeType {
        case positive, negative, neutral
    }

    var body: some View {
        ModernCard(style: .default) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.primaryBlue)
                    .frame(width: 40, height: 40)
                    .background(Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.titleSmall)
                        .foregroundColor(.adaptiveLabel)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.bodySmall)
                            .foregroundColor(.adaptiveSecondaryLabel)
                    }
                }

                Spacer()

                // Value and Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(value)
                        .font(.moneyMedium)
                        .foregroundColor(.adaptiveLabel)

                    if let change = change {
                        HStack(spacing: 4) {
                            Image(systemName: changeType == .positive ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text(change)
                                .font(.labelSmall)
                        }
                        .foregroundColor(changeType == .positive ? .success : .error)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        InfoCard(
            title: "Toplam Portföy",
            subtitle: "Güncel değer",
            icon: "chart.pie.fill",
            value: "$125,430",
            change: "+2.5%",
            changeType: .positive
        )
    }
    .padding()
    .background(Color.adaptiveBackground)
}
