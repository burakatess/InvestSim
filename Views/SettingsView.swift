import SwiftUI

struct SettingsView: View {
    @State private var showContent = false
    @State private var enableBiometrics = true
    @State private var selectedThemeMode: ThemeMode = .system
    @State private var selectedPalette: ColorPalette = .defaultNavy
    @State private var selectedFontScale: FontScale = .medium

    private let supportLinks: [SettingsLinkItem] = [
        .init(title: "FAQ", icon: "book.fill", tint: Color(hex: "#7C4DFF")),
        .init(
            title: "User Guide", icon: "play.rectangle.fill",
            tint: Color(hex: "#7C4DFF")),
        .init(title: "Send Feedback", icon: "paperplane.fill", tint: Color(hex: "#7C4DFF")),
        .init(
            title: "Report Bug", icon: "exclamationmark.triangle.fill",
            tint: Color(hex: "#7C4DFF")),
        .init(title: "About", icon: "info.circle.fill", tint: Color(hex: "#7C4DFF")),
    ]

    private let legalLinks: [SettingsLinkItem] = [
        .init(title: "KVKK / GDPR", icon: "shield.checkerboard", tint: Color(hex: "#7C4DFF")),
        .init(title: "Terms of Use", icon: "doc.text.fill", tint: Color(hex: "#7C4DFF")),
        .init(title: "Privacy Policy", icon: "lock.shield.fill", tint: Color(hex: "#7C4DFF")),
        .init(
            title: "Open Source Licenses", icon: "chevron.left.slash.chevron.right",
            tint: Color(hex: "#7C4DFF")),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#0A1128"), Color(hex: "#050A1E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        profileSection
                        themeSection
                        supportSection
                        legalSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: showContent)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            showContent = true
        }
    }

    private var profileSection: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "#7C4DFF"))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile Information")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Color.white.opacity(0.92))
                        Text("Edit Name, Country and Currency info")
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    Spacer()
                }

                VStack(spacing: 14) {
                    SettingsNavigationRow(
                        title: "Name",
                        subtitle: "Burak Kaya",
                        icon: "person.fill"
                    )
                    Divider().background(Color.white.opacity(0.12))
                    SettingsNavigationRow(
                        title: "Country",
                        subtitle: "United States",
                        icon: "globe.americas.fill"
                    )
                    Divider().background(Color.white.opacity(0.12))
                    SettingsNavigationRow(
                        title: "Currency",
                        subtitle: "US Dollar (USD)",
                        icon: "dollarsign.circle.fill"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Security")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.65))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Protect Portfolio Value with FaceID / TouchID")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Color.white.opacity(0.92))
                            Text("Portfolio value is hidden without biometric authentication.")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.65))
                        }
                        Spacer()
                        Toggle("", isOn: $enableBiometrics)
                            .labelsHidden()
                            .toggleStyle(PremiumToggleStyle())
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var themeSection: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 20) {
                header(
                    title: "Theme & Appearance",
                    subtitle: "Customize app theme and typography")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme Selection")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.65))
                    PremiumSegmentedControl(
                        options: ThemeMode.allCases, selection: $selectedThemeMode)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Color Theme")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.65))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(ColorPalette.allCases) { palette in
                                ColorThemeOptionView(
                                    palette: palette,
                                    isSelected: palette == selectedPalette
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        selectedPalette = palette
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Size")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.65))
                    PremiumSegmentedControl(
                        options: FontScale.allCases, selection: $selectedFontScale)
                }
            }
        }
    }

    private var supportSection: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                header(
                    title: "Support & Help", subtitle: "FAQ, guides and feedback channels")

                VStack(spacing: 0) {
                    ForEach(supportLinks) { item in
                        SettingsLinkRow(item: item)
                        if item.id != supportLinks.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    private var legalSection: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                header(title: "Legal Information", subtitle: "Policies and license details")

                VStack(spacing: 0) {
                    ForEach(legalLinks) { item in
                        SettingsLinkRow(item: item)
                        if item.id != legalLinks.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(Color.white.opacity(0.92))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.65))
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .preferredColorScheme(.dark)
    }
}

// MARK: - Helper Views & Styles

struct PremiumCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color(hex: "#1A1F35").opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hex: "#7C4DFF").opacity(0.2), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.2))
                    .blur(radius: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 12)
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        NavigationLink {
            Text("\(title) settings coming soon.")
                .foregroundColor(.white)
                .padding()
        } label: {
            HStack(spacing: 14) {
                iconBadge
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.92))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .frame(height: 55)
        }
        .buttonStyle(.plain)
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#7C4DFF"))
        }
    }
}

struct SettingsLinkRow: View {
    let item: SettingsLinkItem

    var body: some View {
        NavigationLink {
            Text("\(item.title) page coming soon.")
                .foregroundColor(.white)
                .padding()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.tint.opacity(0.1))
                        .frame(width: 46, height: 46)
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(item.tint)
                }

                Text(item.title)
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.9))

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .frame(height: 55)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct ColorThemeOptionView: View {
    let palette: ColorPalette
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(palette.gradient)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: palette.shadowColor.opacity(0.4), radius: 12, x: 0, y: 6)

                if isSelected {
                    Circle()
                        .stroke(Color(hex: "#7C4DFF").opacity(0.4), lineWidth: 6)
                        .frame(width: 68, height: 68)
                        .blur(radius: 1)
                }
            }

            Text(palette.title)
                .font(.caption)
                .foregroundColor(Color.white.opacity(isSelected ? 0.9 : 0.6))
        }
        .padding(.horizontal, 4)
    }
}

protocol PremiumSegmentOption: CaseIterable, Hashable, Identifiable {
    var title: String { get }
}

extension PremiumSegmentOption where Self: Hashable {
    var id: Self { self }
}

struct PremiumSegmentedControl<Option: PremiumSegmentOption>: View {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    withAnimation(.easeInOut) {
                        selection = option
                    }
                } label: {
                    Text(option.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(
                            selection == option ? Color.white : Color.white.opacity(0.6)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    selection == option
                                        ? Color(hex: "#7C4DFF").opacity(0.2)
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#7C4DFF"), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        )
    }
}

struct PremiumToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    configuration.isOn
                        ? Color(hex: "#7C4DFF").opacity(0.9)
                        : Color.white.opacity(0.15)
                )
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                )
        }
        .buttonStyle(.plain)
        .accessibility(label: Text("Premium Toggle"))
        .accessibility(value: Text(configuration.isOn ? "On" : "Off"))
    }
}

// MARK: - Models

struct SettingsLinkItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
}

enum ThemeMode: String, PremiumSegmentOption, CaseIterable {
    case light, dark, system

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum FontScale: String, PremiumSegmentOption, CaseIterable {
    case small, medium, large

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum ColorPalette: String, CaseIterable, Identifiable {
    case defaultNavy
    case neonPurple
    case sapphireBlue
    case orangeGlow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultNavy: return "Default"
        case .neonPurple: return "Neon Purple"
        case .sapphireBlue: return "Sapphire Blue"
        case .orangeGlow: return "Orange Glow"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .defaultNavy:
            return LinearGradient(
                colors: [Color(hex: "#0A1128"), Color(hex: "#7C4DFF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neonPurple:
            return LinearGradient(
                colors: [Color(hex: "#A855F7"), Color(hex: "#F472B6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sapphireBlue:
            return LinearGradient(
                colors: [Color(hex: "#2563EB"), Color(hex: "#38BDF8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .orangeGlow:
            return LinearGradient(
                colors: [Color(hex: "#F97316"), Color(hex: "#FACC15")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var shadowColor: Color {
        switch self {
        case .defaultNavy: return Color(hex: "#7C4DFF")
        case .neonPurple: return Color(hex: "#A855F7")
        case .sapphireBlue: return Color(hex: "#2563EB")
        case .orangeGlow: return Color(hex: "#F97316")
        }
    }
}
