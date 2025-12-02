import SwiftUI

/// Legacy shim to keep the build happy while the tab uses DashboardView directly.
/// Feed the existing DashboardVM so the view hierarchy stays consistent,
/// but render DashboardView (the new premium dashboard) under the hood.
struct PortfolioView: View {
    @ObservedObject var viewModel: DashboardVM

    var body: some View {
        DashboardView(container: viewModel.container)
    }
}
