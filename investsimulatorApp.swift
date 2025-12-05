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

// MARK: - Welcome / Auth View
struct WelcomeView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isPasswordVisible = false
    @State private var isSignUp = false
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, email, password
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 5 / 255, green: 10 / 255, blue: 35 / 255),
                    Color(red: 11 / 255, green: 17 / 255, blue: 54 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    highlightsSection
                    authCard
                    guestSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .overlay(alignment: .top) {
            if let localError {
                errorBanner(localError)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if authManager.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2))
            }
        }
        .onChange(of: authManager.authState) { _, state in
            if case .authenticated = state {
                localError = nil
            }
        }
        .onChange(of: authManager.latestErrorMessage) { _, message in
            withAnimation {
                localError = message
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("InvestSimulator'a Hoş Geldin")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            Text(
                "DCA planlarını oluştur, senaryoları test et ve gerçek zamanlı fiyatlarla portföyünü takip et."
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.75))
        }
    }

    private var highlightsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                highlightPill(title: "Gerçek zamanlı fiyat")
                highlightPill(title: "Senaryo simülasyonu")
                highlightPill(title: "Modern portföy görünümü")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func highlightPill(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isSignUp ? "Hesap Oluştur" : "Giriş Yap")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                Text(
                    isSignUp
                        ? "Yalnızca ad, e-posta ve şifre ile başla."
                        : "Hızlıca giriş yaparak dashboard'a ulaş."
                )
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            }

            if isSignUp {
                modernTextField(
                    title: "Ad Soyad",
                    text: $fullName,
                    icon: "person.text.rectangle"
                )
                .focused($focusedField, equals: .name)
            }

            modernTextField(
                title: "E-posta veya kullanıcı adı",
                text: $email,
                icon: "envelope.open.fill"
            )
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .email)

            modernSecureField(
                title: "Şifre",
                text: $password,
                icon: "lock.fill"
            )
            .focused($focusedField, equals: .password)

            Button(action: primaryAction) {
                Text(isSignUp ? "Hesap Oluştur" : "E-posta ile giriş yap")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(primaryDisabled ? Color.white.opacity(0.15) : Color(hex: "#7C4DFF"))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(primaryDisabled)

            Button(action: { isSignUp.toggle() }) {
                Text(
                    isSignUp ? "Zaten hesabın var mı? Giriş yap" : "Hesabın yok mu? Hızlıca oluştur"
                )
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.75))
            }
            .padding(.top, -6)

            Divider().background(Color.white.opacity(0.1))

            Button(action: { Task { await authManager.signInWithGoogle() } }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Google ile devam et")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 222 / 255, green: 78 / 255, blue: 64 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 32, x: 0, y: 24)
        )
    }

    private var guestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zaman kaybetmek istemiyor musun?")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
            Text(
                "Misafir modu ile kayıt olmadan portföy kartlarını ve fiyat panelini keşfedebilirsin."
            )
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.65))

            Button(action: {
                Task {
                    await authManager.continueAsGuest()
                }
            }) {
                Text("Misafir olarak devam et")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#20C997"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#20C997"), lineWidth: 1.5)
                    )
            }
        }
    }

    private func modernTextField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.65))
                TextField(title, text: text)
                    .foregroundColor(.white)
                    .disableAutocorrection(true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private func modernSecureField(title: String, text: Binding<String>, icon: String) -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.65))
                Group {
                    if isPasswordVisible {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private func primaryAction() {
        localError = nil
        let trimmedMail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMail.isEmpty, password.count >= 4 else {
            localError =
                "Lütfen geçerli bir e-posta/kullanıcı adı ve en az 4 karakterli şifre girin."
            return
        }

        if isSignUp {
            Task {
                await authManager.signUpWithEmail(
                    email: trimmedMail, password: password,
                    name: fullName.isEmpty ? "Yeni Yatırımcı" : fullName)
            }
        } else {
            Task {
                await authManager.signInWithEmail(email: trimmedMail, password: password)
            }
        }
    }

    private var primaryDisabled: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 4
            || authManager.isLoading
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)
            Spacer(minLength: 0)
            Button {
                withAnimation { localError = nil }
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .padding(.horizontal)
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
