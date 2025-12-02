import SwiftUI

struct RootTabView: View {
    @Environment(\._appContainer) private var container
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var portfolioManager = PortfolioManager()
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var dashboardVM: DashboardVM?
    @State private var selectedTab: TabDestination = .portfolio

    enum TabDestination: Hashable {
        case portfolio, plans, scenarios, prices, settings

        var title: String {
            switch self {
            case .portfolio: return "Portfolio"
            case .plans: return "Plans"
            case .scenarios: return "Scenarios"
            case .prices: return "Prices"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .portfolio: return "wallet.pass"
            case .plans: return "chart.line.uptrend.xyaxis"
            case .scenarios: return "chart.bar"
            case .prices: return "chart.line.flattrend.xyaxis"
            case .settings: return "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .portfolio: return "wallet.pass.fill"
            case .plans: return "chart.line.uptrend.xyaxis"  // same symbol has fill
            case .scenarios: return "chart.bar.fill"
            case .prices: return "chart.line.flattrend.xyaxis"  // no filled variant
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Portföy Tab
            Group {
                if let dashboardVM = dashboardVM {
                    PortfolioView(viewModel: dashboardVM)
                } else {
                    VStack {
                        Text("Loading portfolio...")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        ProgressView()
                    }
                }
            }
            .tabItem {
                tabItemLabel(for: .portfolio)
            }
            .tag(TabDestination.portfolio)

            // Plan Tab
            PlansHomeView(container: container)
                .tabItem {
                    tabItemLabel(for: .plans)
                }
                .tag(TabDestination.plans)

            // Senaryo Tab
            ScenariosHomeView()
                .tabItem {
                    tabItemLabel(for: .scenarios)
                }
                .tag(TabDestination.scenarios)

            // Fiyatlar Tab
            PricesDashboardView(container: container)
                .tabItem {
                    tabItemLabel(for: .prices)
                }
                .tag(TabDestination.prices)

            // Ayarlar Tab
            SettingsView()
                .tabItem {
                    tabItemLabel(for: .settings)
                }
                .tag(TabDestination.settings)
        }
        .tint(accentColor)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial.opacity(0.25), for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            initializeViewModels()
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            appearance.backgroundColor = UIColor.clear
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().unselectedItemTintColor = UIColor(white: 1, alpha: 0.5)
        }
    }

    @ViewBuilder
    private func tabItemLabel(for tab: TabDestination) -> some View {
        let isSelected = selectedTab == tab
        VStack(spacing: 4) {
            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                .renderingMode(.original)
                .foregroundColor(isSelected ? accentColor : Color.white.opacity(0.5))
            Text(tab.title)
                .font(.caption)
                .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.5))
                .padding(.top, 2)
        }
        .padding(.top, 6)
    }

    private func initializeViewModels() {
        dashboardVM = DashboardVM(container: container, portfolioManager: portfolioManager)
        print("DashboardVM initialized successfully")
    }

    private var accentColor: Color {
        Color(red: 124 / 255, green: 77 / 255, blue: 1.0)
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}

// MARK: - Placeholders
struct PlaceholderScenariosView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Scenarios")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                Text("DCA simülasyonları burada olacak")
                    .foregroundColor(.secondary)
                NavigationLink("Yeni Simülasyon", destination: DCAScenarioView())
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
            }
            .padding()
        }
    }
}

struct PlaceholderSettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: .constant(false))
                }
                Section(header: Text("About")) {
                    Text("InvestSimulator v2")
                }
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
