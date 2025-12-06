import SwiftUI

// MARK: - Settings Design System Colors
extension Color {
    fileprivate static let settingsBgStart = Color(hex: "#0B1120")
    fileprivate static let settingsBgMid1 = Color(hex: "#141A33")
    fileprivate static let settingsBgMid2 = Color(hex: "#1A1F3D")
    fileprivate static let settingsBgEnd = Color(hex: "#2A2F5C")
    fileprivate static let settingsAccentPurple = Color(hex: "#7C4DFF")
    fileprivate static let settingsAccentCyan = Color(hex: "#4CC9F0")
}

// MARK: - Glass Card Component
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.20))
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
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
                    .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 16)
            )
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Toggle Row Component
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .settingsAccentPurple))
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Settings Segmented Control
struct SettingsSegmentedControl<T: Hashable & CaseIterable & RawRepresentable>: View
where T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(T.allCases), id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selection == option ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Group {
                                if selection == option {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .settingsAccentPurple, .settingsAccentCyan,
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(
                                            color: .settingsAccentPurple.opacity(0.3), radius: 8,
                                            x: 0, y: 4)
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Color Theme Selector
struct ColorThemeSelector: View {
    @Binding var selectedTheme: AppColorTheme

    var body: some View {
        HStack(spacing: 16) {
            ForEach(AppColorTheme.allCases, id: \.self) { theme in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTheme = theme
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: theme.primaryColor.opacity(selectedTheme == theme ? 0.6 : 0),
                                radius: 10, x: 0, y: 4)

                        if selectedTheme == theme {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 44, height: 44)

                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            Spacer()
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.92))

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
}

// MARK: - Enums for Settings
enum AppThemeMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

enum AppColorTheme: String, CaseIterable {
    case defaultNavy = "Default"
    case neonPurple = "Neon"
    case sapphireBlue = "Sapphire"
    case orangeBurst = "Orange"

    var primaryColor: Color {
        switch self {
        case .defaultNavy: return Color(hex: "#7C4DFF")
        case .neonPurple: return Color(hex: "#E040FB")
        case .sapphireBlue: return Color(hex: "#00BCD4")
        case .orangeBurst: return Color(hex: "#FF6D00")
        }
    }
}

enum AppFontSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
}

// MARK: - Settings View (Premium Fintech Design)
struct SettingsView: View {
    // MARK: - State
    @State private var userName = "Burak Kaya"
    @State private var userCountry = "Türkiye"
    @State private var userCurrency = "USD"
    @State private var enableBiometrics = true
    @State private var selectedThemeMode: AppThemeMode = .system
    @State private var selectedColorTheme: AppColorTheme = .defaultNavy
    @State private var selectedFontSize: AppFontSize = .medium
    @State private var isAppearing = false

    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .settingsBgStart, location: 0.0),
                    .init(color: .settingsBgMid1, location: 0.3),
                    .init(color: .settingsBgMid2, location: 0.6),
                    .init(color: .settingsBgEnd, location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial glows
            RadialGradient(
                colors: [.settingsAccentPurple.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                colors: [.settingsAccentCyan.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Profile", subtitle: "Your account information")

                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "person.fill",
                        iconColor: .settingsAccentPurple,
                        title: "Name",
                        subtitle: userName
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "globe",
                        iconColor: .settingsAccentCyan,
                        title: "Country",
                        subtitle: userCountry
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "dollarsign.circle.fill",
                        iconColor: Color(hex: "#4CAF50"),
                        title: "Currency",
                        subtitle: userCurrency
                    )
                }
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Security Section
    private var securitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Security", subtitle: "Protect your data")

                SettingsToggleRow(
                    icon: "faceid",
                    iconColor: .settingsAccentPurple,
                    title: "Biometric Lock",
                    subtitle: "Protect portfolio with Face ID / Touch ID",
                    isOn: $enableBiometrics
                )
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Theme Section
    private var themeSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Theme & Appearance", subtitle: "Customize your experience")

                // Theme Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("THEME MODE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))

                    SettingsSegmentedControl(selection: $selectedThemeMode)
                }

                // Color Theme
                VStack(alignment: .leading, spacing: 12) {
                    Text("COLOR THEME")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))

                    ColorThemeSelector(selectedTheme: $selectedColorTheme)
                }

                // Font Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("FONT SIZE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))

                    SettingsSegmentedControl(selection: $selectedFontSize)
                }
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Support Section
    private var supportSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    title: "Support & Help", subtitle: "Get assistance and share feedback")

                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "questionmark.circle.fill",
                        iconColor: .settingsAccentCyan,
                        title: "FAQ",
                        subtitle: "Frequently asked questions"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "book.fill",
                        iconColor: Color(hex: "#FF9800"),
                        title: "User Guide",
                        subtitle: "Learn how to use the app"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "envelope.fill",
                        iconColor: .settingsAccentPurple,
                        title: "Send Feedback",
                        subtitle: "Share your thoughts with us"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "ant.fill",
                        iconColor: Color(hex: "#F44336"),
                        title: "Report Bug",
                        subtitle: "Help us fix issues"
                    )
                }
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Legal Information", subtitle: "Terms, privacy and licenses")

                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "shield.checkered",
                        iconColor: .settingsAccentCyan,
                        title: "KVKK / GDPR",
                        subtitle: "Data protection compliance"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "doc.text.fill",
                        iconColor: .settingsAccentPurple,
                        title: "Terms of Use",
                        subtitle: "Service agreement"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "lock.shield.fill",
                        iconColor: Color(hex: "#4CAF50"),
                        title: "Privacy Policy",
                        subtitle: "How we handle your data"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 50)

                    SettingsRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        iconColor: Color(hex: "#FF9800"),
                        title: "Open Source Licenses",
                        subtitle: "Third-party attributions"
                    )
                }
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - App Version
    private var appVersionSection: some View {
        VStack(spacing: 8) {
            Text("InvestSimulator")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Text("Version 2.0.0 (Build 2025.12)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .opacity(isAppearing ? 1 : 0)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileSection
                        securitySection
                        themeSection
                        supportSection
                        legalSection
                        appVersionSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
