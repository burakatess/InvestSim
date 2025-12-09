import Combine
import LocalAuthentication
import MessageUI
import Security
import SwiftUI
import UIKit

// MARK: - Biometric Manager (Inline)
@MainActor
final class SettingsBiometricManager: ObservableObject {
    static let shared = SettingsBiometricManager()

    @Published var isBiometricEnabled: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var isLocked: Bool = false
    @Published var autoLockInterval: AutoLockInterval = .oneMinute

    enum BiometricType {
        case faceID, touchID, none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "Biometric"
            }
        }

        var iconName: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .none: return "lock.shield"
            }
        }
    }

    enum AutoLockInterval: String, CaseIterable {
        case fifteenSeconds = "15 sec"
        case thirtySeconds = "30 sec"
        case oneMinute = "1 min"
        case fiveMinutes = "5 min"

        var seconds: TimeInterval {
            switch self {
            case .fifteenSeconds: return 15
            case .thirtySeconds: return 30
            case .oneMinute: return 60
            case .fiveMinutes: return 300
            }
        }
    }

    private let keychainKey = "BiometricEnabled"
    private let autoLockKey = "AutoLockInterval"

    private init() {
        loadSettings()
        checkBiometricType()
    }

    func isBiometricAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func enableBiometric() async -> Bool {
        guard isBiometricAvailable() else { return false }
        let success = await authenticate(reason: "Enable \(biometricType.displayName)")
        if success {
            isBiometricEnabled = true
            saveBiometricEnabled(true)
        }
        return success
    }

    func disableBiometric() {
        isBiometricEnabled = false
        saveBiometricEnabled(false)
    }

    func authenticate(reason: String = "Authenticate") async -> Bool {
        guard isBiometricAvailable() else { return false }
        do {
            let success = try await LAContext().evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success { await MainActor.run { isLocked = false } }
            return success
        } catch { return false }
    }

    func forceLock() { isLocked = true }

    func setAutoLockInterval(_ interval: AutoLockInterval) {
        autoLockInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: autoLockKey)
    }

    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
            biometricType = .none
            return
        }
        biometricType = context.biometryType == .faceID ? .faceID : .touchID
    }

    private func loadSettings() {
        isBiometricEnabled = loadBiometricEnabled()
        if let interval = UserDefaults.standard.string(forKey: autoLockKey),
            let val = AutoLockInterval(rawValue: interval)
        {
            autoLockInterval = val
        }
        if isBiometricEnabled { isLocked = true }
    }

    private func saveBiometricEnabled(_ enabled: Bool) {
        let data = Data([enabled ? 1 : 0])
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadBiometricEnabled() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data, let byte = data.first
        {
            return byte == 1
        }
        return false
    }
}

// MARK: - Settings Design System Colors
extension Color {
    fileprivate static let settingsBgStart = Color(hex: "#0B1120")
    fileprivate static let settingsBgMid1 = Color(hex: "#141A33")
    fileprivate static let settingsBgMid2 = Color(hex: "#1A1F3D")
    fileprivate static let settingsBgEnd = Color(hex: "#2A2F5C")
    fileprivate static let settingsAccentPurple = Color(hex: "#7C4DFF")
    fileprivate static let settingsAccentCyan = Color(hex: "#4CC9F0")
}

// MARK: - Glass Card
private struct SettingsGlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.20))
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.04)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 16)
            )
    }
}

// MARK: - Settings Row
private struct SettingsRowItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 13)).foregroundColor(.white.opacity(0.55))
                    }
                }
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Toggle
private struct SettingsToggleItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(
                    .white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                if let subtitle {
                    Text(subtitle).font(.system(size: 13)).foregroundColor(.white.opacity(0.55))
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(SwitchToggleStyle(tint: .settingsAccentPurple))
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Section Header
private struct SettingsSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundColor(.white.opacity(0.92))
            if let subtitle {
                Text(subtitle).font(.system(size: 14, weight: .medium)).foregroundColor(
                    .white.opacity(0.55))
            }
        }
    }
}

// MARK: - FAQ View
private struct SettingsFAQView: View {
    private let items = [
        (
            "InvestSimulator nedir?",
            "Yatırım simülasyonu yapmanızı sağlayan, risk almadan portföy yönetimi deneyimi kazandıran bir uygulamadır."
        ),
        (
            "Fiyatlar ne sıklıkla güncellenir?",
            "Kripto anlık, hisseler dakikada bir, forex 5 dakikada bir güncellenir."
        ),
        (
            "DCA nedir?",
            "Dollar Cost Averaging - belirli aralıklarla sabit miktarda yatırım yapma stratejisi."
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")], startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(items.indices, id: \.self) { i in
                        FAQItemView(question: items[i].0, answer: items[i].1)
                    }
                }.padding(20)
            }
        }
        .navigationTitle("FAQ")
    }
}

private struct FAQItemView: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring()) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(question).font(.system(size: 16, weight: .semibold)).foregroundColor(
                        .white
                    ).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(
                        .white.opacity(0.5))
                }
            }
            if isExpanded {
                Text(answer).font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                    .lineSpacing(4)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - User Guide View
private struct SettingsUserGuideView: View {
    private let steps = [
        (
            "chart.line.uptrend.xyaxis", "Fiyatları Takip Et",
            "Prices sekmesinden tüm fiyatları anlık takip edin."
        ),
        ("briefcase.fill", "Portföy Oluştur", "Portfolio sekmesinden varlıklarınızı ekleyin."),
        ("waveform.path.ecg", "Senaryo Simülasyonu", "Scenarios'dan DCA stratejileri oluşturun."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")], startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "book.fill").font(.system(size: 48)).foregroundColor(
                        Color(hex: "#7C4DFF")
                    ).padding(.top)
                    Text("Kullanım Rehberi").font(.system(size: 24, weight: .bold)).foregroundColor(
                        .white)
                    ForEach(steps.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#7C4DFF"), Color(hex: "#4CC9F0")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                ).frame(width: 32, height: 32)
                                Text("\(i + 1)").font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: steps[i].0).foregroundColor(
                                        Color(hex: "#7C4DFF"))
                                    Text(steps[i].1).font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text(steps[i].2).font(.system(size: 14)).foregroundColor(
                                    .white.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(16).background(
                            RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
                    }
                }.padding(20)
            }
        }
        .navigationTitle("User Guide")
    }
}

// MARK: - Report Bug View
private struct SettingsReportBugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")], startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "ant.fill").font(.system(size: 40)).foregroundColor(
                        Color(hex: "#F44336"))
                    Text("Hata Bildir").font(.system(size: 22, weight: .bold)).foregroundColor(
                        .white)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BAŞLIK").font(.system(size: 12, weight: .semibold)).foregroundColor(
                            .white.opacity(0.5))
                        TextField("", text: $title).padding(12).background(
                            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                        ).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AÇIKLAMA").font(.system(size: 12, weight: .semibold)).foregroundColor(
                            .white.opacity(0.5))
                        TextEditor(text: $description).scrollContentBackground(.hidden).frame(
                            minHeight: 100
                        ).padding(12).background(
                            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                        ).foregroundColor(.white)
                    }
                    Button {
                        showSuccess = true
                    } label: {
                        Text("Gönder").font(.system(size: 16, weight: .semibold)).foregroundColor(
                            .white
                        ).frame(maxWidth: .infinity).frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#7C4DFF"), Color(hex: "#4CC9F0")],
                                    startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }.disabled(title.isEmpty).opacity(title.isEmpty ? 0.5 : 1)
                }.padding(20)
            }
        }
        .navigationTitle("Report Bug")
        .alert("Teşekkürler!", isPresented: $showSuccess) {
            Button("Tamam") { dismiss() }
        } message: {
            Text("Bug raporunuz gönderildi.")
        }
    }
}

// MARK: - Legal Document View
private struct SettingsLegalView: View {
    let title: String
    let content: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")], startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ScrollView {
                Text(content).font(.system(size: 14)).foregroundColor(.white.opacity(0.8))
                    .lineSpacing(6).padding(20)
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Mail Composer
private struct SettingsMailComposer: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let recipient: String
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
    }
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(
            _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult,
            error: Error?
        ) { dismiss() }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var biometricManager = SettingsBiometricManager.shared
    @State private var isAppearing = false
    @State private var showMailComposer = false
    @State private var showSignOutAlert = false

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .settingsBgStart, location: 0.0),
                    .init(color: .settingsBgMid1, location: 0.3),
                    .init(color: .settingsBgMid2, location: 0.6),
                    .init(color: .settingsBgEnd, location: 1.0),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(
                colors: [.settingsAccentPurple.opacity(0.12), .clear], center: .topTrailing,
                startRadius: 50, endRadius: 400)
            RadialGradient(
                colors: [.settingsAccentCyan.opacity(0.08), .clear], center: .bottomLeading,
                startRadius: 50, endRadius: 350)
        }.ignoresSafeArea()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileSection
                        securitySection
                        supportSection
                        legalSection
                        appVersionSection
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
        .sheet(isPresented: $showMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                SettingsMailComposer(
                    recipient: "support@investsimulator.app", subject: "App Feedback",
                    body:
                        "\n\n---\nDevice: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
                )
            }
        }
        .alert("Çıkış Yap", isPresented: $showSignOutAlert) {
            Button("İptal", role: .cancel) {}
            Button("Çıkış Yap", role: .destructive) { Task { await authManager.signOut() } }
        } message: {
            Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?")
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        SettingsGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader(title: "Profile", subtitle: "Your account information")
                if authManager.isGuest { guestProfileView } else { authenticatedProfileView }
            }
        }.opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)
    }

    private var guestProfileView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "person.fill.questionmark").font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Misafir Kullanıcı").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Tüm özelliklere erişmek için kayıt olun").font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            Button {
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Hesap Oluştur")
                }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(
                    maxWidth: .infinity
                ).frame(height: 46)
                .background(
                    LinearGradient(
                        colors: [.settingsAccentPurple, .settingsAccentCyan], startPoint: .leading,
                        endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var authenticatedProfileView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(
                        LinearGradient(
                            colors: [.settingsAccentPurple, .settingsAccentCyan],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    ).frame(width: 56, height: 56)
                    Text(String(authManager.currentUser?.name?.prefix(1) ?? "U").uppercased()).font(
                        .system(size: 22, weight: .bold)
                    ).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.currentUser?.name ?? "User").font(
                        .system(size: 18, weight: .semibold)
                    ).foregroundColor(.white)
                    Text(authManager.currentUser?.email ?? "").font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }.padding(.bottom, 16)
            Divider().background(Color.white.opacity(0.1))
            SettingsRowItem(
                icon: "globe", iconColor: .settingsAccentCyan, title: "Country", subtitle: "Türkiye"
            )
            Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
            SettingsRowItem(
                icon: "dollarsign.circle.fill", iconColor: Color(hex: "#4CAF50"), title: "Currency",
                subtitle: "USD")
            Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
            SettingsRowItem(
                icon: "rectangle.portrait.and.arrow.right", iconColor: Color(hex: "#F44336"),
                title: "Sign Out", showChevron: false
            ) { showSignOutAlert = true }
        }
    }

    // MARK: - Security Section
    private var securitySection: some View {
        SettingsGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader(title: "Security", subtitle: "Protect your data")
                VStack(spacing: 0) {
                    SettingsToggleItem(
                        icon: biometricManager.biometricType.iconName,
                        iconColor: .settingsAccentPurple, title: "Biometric Lock",
                        subtitle: "Protect with \(biometricManager.biometricType.displayName)",
                        isOn: Binding(
                            get: { biometricManager.isBiometricEnabled },
                            set: { v in
                                Task {
                                    if v {
                                        _ = await biometricManager.enableBiometric()
                                    } else {
                                        biometricManager.disableBiometric()
                                    }
                                }
                            }))
                    if biometricManager.isBiometricEnabled {
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(
                                    LinearGradient(
                                        colors: [
                                            .settingsAccentCyan, .settingsAccentCyan.opacity(0.7),
                                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                ).frame(width: 36, height: 36)
                                Image(systemName: "timer").font(
                                    .system(size: 16, weight: .semibold)
                                ).foregroundColor(.white)
                            }
                            Text("Auto-Lock").font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Picker(
                                "",
                                selection: Binding(
                                    get: { biometricManager.autoLockInterval },
                                    set: { biometricManager.setAutoLockInterval($0) })
                            ) {
                                ForEach(
                                    SettingsBiometricManager.AutoLockInterval.allCases, id: \.self
                                ) { Text($0.rawValue).tag($0) }
                            }.pickerStyle(.menu).tint(.white)
                        }.padding(.vertical, 6)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                        SettingsRowItem(
                            icon: "lock.fill", iconColor: Color(hex: "#FF9800"),
                            title: "Force Lock Now", showChevron: false
                        ) { biometricManager.forceLock() }
                    }
                }
            }
        }.opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Support Section
    private var supportSection: some View {
        SettingsGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader(title: "Support & Help", subtitle: "Get assistance")
                VStack(spacing: 0) {
                    NavigationLink {
                        SettingsFAQView()
                    } label: {
                        SettingsRowItem(
                            icon: "questionmark.circle.fill", iconColor: .settingsAccentCyan,
                            title: "FAQ", subtitle: "Frequently asked questions")
                    }
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                    NavigationLink {
                        SettingsUserGuideView()
                    } label: {
                        SettingsRowItem(
                            icon: "book.fill", iconColor: Color(hex: "#FF9800"),
                            title: "User Guide", subtitle: "Learn how to use")
                    }
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                    SettingsRowItem(
                        icon: "envelope.fill", iconColor: .settingsAccentPurple,
                        title: "Send Feedback", subtitle: "Share your thoughts"
                    ) { if MFMailComposeViewController.canSendMail() { showMailComposer = true } }
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                    NavigationLink {
                        SettingsReportBugView()
                    } label: {
                        SettingsRowItem(
                            icon: "ant.fill", iconColor: Color(hex: "#F44336"), title: "Report Bug",
                            subtitle: "Help us fix issues")
                    }
                }
            }
        }.opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        SettingsGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader(title: "Legal", subtitle: "Terms and privacy")
                VStack(spacing: 0) {
                    NavigationLink {
                        SettingsLegalView(title: "KVKK / GDPR", content: kvkkContent)
                    } label: {
                        SettingsRowItem(
                            icon: "shield.checkered", iconColor: .settingsAccentCyan,
                            title: "KVKK / GDPR", subtitle: "Data protection")
                    }
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                    NavigationLink {
                        SettingsLegalView(title: "Terms of Use", content: termsContent)
                    } label: {
                        SettingsRowItem(
                            icon: "doc.text.fill", iconColor: .settingsAccentPurple,
                            title: "Terms of Use", subtitle: "Service agreement")
                    }
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                    NavigationLink {
                        SettingsLegalView(title: "Privacy Policy", content: privacyContent)
                    } label: {
                        SettingsRowItem(
                            icon: "lock.shield.fill", iconColor: Color(hex: "#4CAF50"),
                            title: "Privacy Policy", subtitle: "How we handle data")
                    }
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 50)
                    NavigationLink {
                        SettingsLegalView(title: "Open Source", content: openSourceContent)
                    } label: {
                        SettingsRowItem(
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: Color(hex: "#FF9800"), title: "Open Source",
                            subtitle: "Third-party licenses")
                    }
                }
            }
        }.opacity(isAppearing ? 1 : 0).offset(y: isAppearing ? 0 : 20)
    }

    private var kvkkContent: String {
        "KVKK VE GDPR UYUM POLİTİKASI\n\nInvestSimulator, 6698 sayılı KVKK ve GDPR hükümlerine uygun hareket eder.\n\nToplanan Veriler:\n• Kimlik bilgileri\n• Hesap bilgileri\n• Kullanım verileri\n\nHaklarınız:\n• Verilerinize erişim\n• Düzeltme talep etme\n• Silme talep etme"
    }
    private var termsContent: String {
        "KULLANIM KOŞULLARI\n\nInvestSimulator uygulamasını kullanarak bu koşulları kabul edersiniz.\n\nUygulama yalnızca eğitim amaçlıdır ve gerçek yatırım tavsiyesi sunmaz.\n\nTüm içerik ve tasarım InvestSimulator'a aittir."
    }
    private var privacyContent: String {
        "GİZLİLİK POLİTİKASI\n\nBilgilerinizi şu amaçlarla kullanıyoruz:\n• Hizmet sunumu\n• Güvenlik sağlama\n• Ürün geliştirme\n\nVerilerinizi pazarlama amaçlı üçüncü taraflarla paylaşmıyoruz."
    }
    private var openSourceContent: String {
        "AÇIK KAYNAK LİSANSLARI\n\n• Supabase Swift - MIT License\n• Google Sign-In - Apache 2.0\n• Charts - Apache 2.0\n• Lottie - Apache 2.0"
    }

    // MARK: - App Version
    private var appVersionSection: some View {
        VStack(spacing: 8) {
            Text("InvestSimulator").font(.system(size: 16, weight: .semibold)).foregroundColor(
                .white.opacity(0.6))
            Text("Version 2.0.0 (Build 2025.12)").font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
            Text("© 2025 All rights reserved").font(.system(size: 11)).foregroundColor(
                .white.opacity(0.25))
        }.frame(maxWidth: .infinity).padding(.vertical, 20).opacity(isAppearing ? 1 : 0)
    }
}

#Preview { SettingsView().environmentObject(AuthenticationManager.shared) }
