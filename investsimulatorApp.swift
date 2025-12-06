import Combine
import CoreData
import SwiftUI
import UIKit
import UserNotifications

@main
struct InvestSimApp: App {
    @StateObject private var container = AppContainer(mockMode: false)
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var userDataManager = UserDataManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        configureNavigationAppearance(largeColor: UIColor.white, inlineColor: UIColor.white)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else {
                    switch authManager.authState {
                    case .loading:
                        SplashView()
                    case .authenticated(let user):
                        RootTabView()
                            .environment(\._appContainer, container)
                            .environmentObject(authManager)
                            .environmentObject(userDataManager)
                            .onAppear {
                                userDataManager.switchUser(userId: user.id)

                                // Initialize dynamic asset catalog
                                Task {
                                    print("🚀 Initializing dynamic asset catalog...")
                                    // Force sync on first launch to ensure all categories load
                                    await AssetCatalogManager.shared.forceSync()
                                }

                                // Start background sync scheduler
                                AssetSyncScheduler.shared.start()

                                // Start background sync scheduler
                                AssetSyncScheduler.shared.start()
                            }
                    case .unauthenticated:
                        WelcomeView()
                            .environmentObject(authManager)
                    case .error(let message):
                        ErrorView(message: message) {
                            authManager.authState = .unauthenticated
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.primaryBlue)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

            Text("InvestSimulator")
                .font(.displayLarge)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Bir Hata Oluştu")
                    .font(.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text(message)
                    .font(.bodyLarge)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: retryAction) {
                Text("Tekrar Dene")
                    .font(.buttonLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primaryBlue)
                    )
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Welcome / Auth View (Premium Fintech Design)

// MARK: - Design System Colors
extension Color {
    fileprivate static let bgGradientStart = Color(hex: "#0B1120")
    fileprivate static let bgGradientMid1 = Color(hex: "#141A33")
    fileprivate static let bgGradientMid2 = Color(hex: "#1A1F3D")
    fileprivate static let bgGradientEnd = Color(hex: "#2A2F5C")
    fileprivate static let accentPurple = Color(hex: "#7C4DFF")
    fileprivate static let accentCyan = Color(hex: "#4CC9F0")
    fileprivate static let glassWhite = Color.white.opacity(0.08)
    fileprivate static let glassBorder = Color.white.opacity(0.12)
}

// MARK: - Glass Container Modifier
struct GlassContainer: ViewModifier {
    var cornerRadius: CGFloat = 28
    var opacity: Double = 0.18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(opacity))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 40, x: 0, y: 20)
            )
    }
}

extension View {
    func glassContainer(cornerRadius: CGFloat = 28, opacity: Double = 0.18) -> some View {
        modifier(GlassContainer(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Premium Input Field
struct PremiumInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @Binding var isPasswordVisible: Bool
    var contentType: UITextContentType?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            if isSecure && !isPasswordVisible {
                SecureField(
                    "", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35))
                )
                .foregroundColor(.white)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } else {
                TextField(
                    "", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35))
                )
                .foregroundColor(.white)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(contentType == .emailAddress ? .emailAddress : .default)
            }

            if isSecure {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPasswordVisible.toggle()
                    }
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Gradient Button
struct GradientButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if isDisabled {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.accentPurple, .accentCyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .accentPurple.opacity(0.4), radius: 16, x: 0, y: 8)
                        }
                    }
                )
        }
        .disabled(isDisabled)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Google Button
struct GoogleButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .light)
            impactMed.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                // Google "G" icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)

                    Text("G")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#EA4335"), Color(hex: "#FBBC05"),
                                    Color(hex: "#34A853"), Color(hex: "#4285F4"),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Google ile devam et")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Guest Button
struct GuestButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .light)
            impactMed.impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 16, weight: .medium))

                Text("Misafir olarak devam et")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.accentCyan)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentCyan.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentCyan.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: .accentCyan.opacity(0.2), radius: 12, x: 0, y: 4)
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - WelcomeView (Premium Fintech Login)
struct WelcomeView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isPasswordVisible = false
    @State private var isSignUp = false
    @State private var localError: String?
    @State private var isAppearing = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, email, password
    }

    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                stops: [
                    .init(color: .bgGradientStart, location: 0.0),
                    .init(color: .bgGradientMid1, location: 0.3),
                    .init(color: .bgGradientMid2, location: 0.6),
                    .init(color: .bgGradientEnd, location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial glow
            RadialGradient(
                colors: [.accentPurple.opacity(0.15), .clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                colors: [.accentCyan.opacity(0.1), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentPurple, .accentCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: .accentPurple.opacity(0.4), radius: 20, x: 0, y: 10)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isAppearing ? 1.0 : 0.5)
            .opacity(isAppearing ? 1.0 : 0)

            VStack(spacing: 8) {
                Text("InvestSimulator")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Akıllı yatırım, sadeleştirilmiş.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(isAppearing ? 1.0 : 0)
            .offset(y: isAppearing ? 0 : 20)
        }
        .padding(.top, 40)
    }

    // MARK: - Login Card
    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Card Header
            VStack(alignment: .leading, spacing: 6) {
                Text(isSignUp ? "Hesap Oluştur" : "Giriş Yap")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(isSignUp ? "Yatırım yolculuğuna başla." : "Hesabına giriş yap.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Input Fields
            VStack(spacing: 14) {
                if isSignUp {
                    PremiumInputField(
                        icon: "person.fill",
                        placeholder: "Ad Soyad",
                        text: $fullName,
                        isSecure: false,
                        isPasswordVisible: .constant(true),
                        contentType: .name
                    )
                    .focused($focusedField, equals: .name)
                }

                PremiumInputField(
                    icon: "envelope.fill",
                    placeholder: "E-posta adresi",
                    text: $email,
                    isSecure: false,
                    isPasswordVisible: .constant(true),
                    contentType: .emailAddress
                )
                .focused($focusedField, equals: .email)

                PremiumInputField(
                    icon: "lock.fill",
                    placeholder: "Şifre",
                    text: $password,
                    isSecure: true,
                    isPasswordVisible: $isPasswordVisible,
                    contentType: .password
                )
                .focused($focusedField, equals: .password)
            }

            // Primary Action Button
            GradientButton(
                title: isSignUp ? "Hesap Oluştur" : "E-posta ile giriş yap",
                action: primaryAction,
                isDisabled: primaryDisabled
            )

            // Toggle Sign Up / Sign In
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isSignUp.toggle()
                    fullName = ""
                }
            } label: {
                Text(
                    isSignUp
                        ? "Zaten hesabın var mı? **Giriş yap**"
                        : "Hesabın yok mu? **Hızlıca oluştur**"
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            // Divider
            HStack(spacing: 16) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)

                Text("veya")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
            }

            // Google Button
            GoogleButton {
                Task { await authManager.signInWithGoogle() }
            }
        }
        .padding(24)
        .glassContainer()
        .opacity(isAppearing ? 1.0 : 0)
        .offset(y: isAppearing ? 0 : 30)
    }

    // MARK: - Guest Section
    private var guestSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Hızlıca keşfetmek ister misin?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Text("Kayıt olmadan portföy ve fiyatları incele.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            GuestButton {
                Task { await authManager.continueAsGuest() }
            }
        }
        .opacity(isAppearing ? 1.0 : 0)
        .offset(y: isAppearing ? 0 : 20)
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yellow)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring()) { localError = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    headerSection
                    loginCard
                    guestSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            // Error overlay
            if let error = localError {
                VStack {
                    errorBanner(error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }

            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.3)

                            Text("Giriş yapılıyor...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                isAppearing = true
            }
        }
        .onChange(of: authManager.authState) { _, state in
            if case .authenticated = state {
                localError = nil
            }
        }
        .onChange(of: authManager.latestErrorMessage) { _, message in
            withAnimation(.spring()) {
                localError = message
            }
        }
        .animation(.spring(), value: isSignUp)
    }

    // MARK: - Actions
    private func primaryAction() {
        localError = nil
        focusedField = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, password.count >= 4 else {
            withAnimation(.spring()) {
                localError = "Lütfen geçerli bir e-posta ve en az 4 karakterli şifre girin."
            }
            return
        }

        if isSignUp {
            Task {
                await authManager.signUpWithEmail(
                    email: trimmedEmail,
                    password: password,
                    name: fullName.isEmpty ? "Yeni Yatırımcı" : fullName
                )
            }
        } else {
            Task {
                await authManager.signInWithEmail(email: trimmedEmail, password: password)
            }
        }
    }

    private var primaryDisabled: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 4
            || authManager.isLoading
    }
}

// MARK: - Onboarding Implementation

class OnboardingViewModel: ObservableObject {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @Published var currentPage: Int = 0

    let pages: [OnboardingPageData] = [
        OnboardingPageData(
            title: "InvestSimulator'a Hoş Geldin",
            description:
                "Yatırım dünyasını risksiz keşfet. Gerçek piyasa verileriyle stratejilerini geliştir.",
            imageName: "chart.line.uptrend.xyaxis",
            color: Color(hex: "#4A90E2")
        ),
        OnboardingPageData(
            title: "Portföyünü Takip Et",
            description:
                "Tüm varlıklarını tek bir yerden yönet. Kripto, Borsa, Altın ve Döviz kurlarını anlık izle.",
            imageName: "briefcase.fill",
            color: Color(hex: "#50E3C2")
        ),
        OnboardingPageData(
            title: "Stratejilerini Test Et",
            description:
                "Geçmiş verilerle DCA (Dolar Cost Averaging) senaryoları oluştur ve performansını gör.",
            imageName: "slider.horizontal.3",
            color: Color(hex: "#F5A623")
        ),
        OnboardingPageData(
            title: "Otomatik Planlar",
            description:
                "Düzenli yatırım planları oluştur. Hedeflerine ulaşmak için disiplinli bir yol haritası çiz.",
            imageName: "calendar",
            color: Color(hex: "#9013FE")
        ),
    ]

    func completeOnboarding() {
        withAnimation {
            hasSeenOnboarding = true
        }
    }

    func nextPage() {
        withAnimation {
            if currentPage < pages.count - 1 {
                currentPage += 1
            } else {
                completeOnboarding()
            }
        }
    }
}

struct OnboardingPageData: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#050B1F"), Color(hex: "#101530")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Content
                TabView(selection: $viewModel.currentPage) {
                    ForEach(0..<viewModel.pages.count, id: \.self) { index in
                        OnboardingPageView(data: viewModel.pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentPage)

                // Bottom Controls
                VStack(spacing: 24) {
                    // Page Indicators
                    HStack(spacing: 8) {
                        ForEach(0..<viewModel.pages.count, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == viewModel.currentPage
                                        ? viewModel.pages[index].color : Color.white.opacity(0.2)
                                )
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == viewModel.currentPage ? 1.2 : 1.0)
                                .animation(.spring(), value: viewModel.currentPage)
                        }
                    }

                    // Action Button
                    Button(action: viewModel.nextPage) {
                        Text(
                            viewModel.currentPage == viewModel.pages.count - 1 ? "Başla" : "İlerle"
                        )
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            viewModel.pages[viewModel.currentPage].color
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(
                            color: viewModel.pages[viewModel.currentPage].color.opacity(0.3),
                            radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
    }
}

struct OnboardingPageView: View {
    let data: OnboardingPageData
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(data.color.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)

                Image(systemName: data.imageName)
                    .font(.system(size: 80))
                    .foregroundColor(data.color)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.0)
            }

            // Text
            VStack(spacing: 16) {
                Text(data.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)

                Text(data.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }
}
