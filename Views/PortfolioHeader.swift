import SwiftUI

private enum PortfolioHeaderColors {
    static let cardTop = Color(hex: "#1B1F3B")
    static let cardBottom = Color(hex: "#11132A")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let border = Color.white.opacity(0.12)
}

struct PortfolioHeader: View {
    @ObservedObject var portfolioManager: PortfolioManager
    @State private var showingPortfolioMenu = false
    @State private var showingAddPortfolio = false
    @State private var showingEditPortfolio = false
    @State private var selectedPortfolio: Portfolio?
    @State private var isDarkMode = false

    // Header özellikleri için binding'ler
    @Binding var showingExportOptions: Bool
    @Binding var showingRealtimePrices: Bool
    @Binding var isHidden: Bool

    // UnifiedPriceManager için environment
    @Environment(\._appContainer) private var container

    var body: some View {
        VStack(spacing: 12) {
            // Üst Satır: Portfolio Dropdown
            HStack {
                Button(action: {
                    showingPortfolioMenu = true
                }) {
                    HStack(spacing: 8) {
                        // Portfolio Icon
                        if let portfolio = portfolioManager.currentPortfolio {
                            Image(systemName: portfolio.color.icon)
                                .font(.title2)
                                .foregroundColor(portfolio.color.color)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(portfolio.color.color.opacity(0.25))
                                )
                        }

                        // Portfolio Name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(portfolioManager.currentPortfolio?.name ?? "Portfolio")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(PortfolioHeaderColors.textPrimary)

                            Text("\(portfolioManager.portfolios.count) portfolios")
                                .font(.caption)
                                .foregroundColor(PortfolioHeaderColors.textSecondary)
                        }

                        Spacer()

                        // Dropdown Arrow
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(PortfolioHeaderColors.textSecondary)
                            .rotationEffect(.degrees(showingPortfolioMenu ? 180 : 0))
                            .animation(.easeInOut(duration: 0.2), value: showingPortfolioMenu)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                PortfolioHeaderColors.cardTop, PortfolioHeaderColors.cardBottom,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PortfolioHeaderColors.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.4 : 0.2), radius: 14, y: 8)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }

            // Alt Satır: Action Buttons (KALDIRILDI)
            // Butonlar PortfolioMenuView içine taşındı.
        }
        .onAppear {
            isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
        .sheet(isPresented: $showingPortfolioMenu) {
            PortfolioMenuView(
                portfolioManager: portfolioManager,
                showingEditPortfolio: $showingEditPortfolio,
                selectedPortfolio: $selectedPortfolio,
                showingExportOptions: $showingExportOptions,
                showingRealtimePrices: $showingRealtimePrices,
                isHidden: $isHidden,
                showingAddPortfolio: $showingAddPortfolio
            )
        }
        .sheet(isPresented: $showingAddPortfolio) {
            AddPortfolioView(portfolioManager: portfolioManager)
        }
        .sheet(isPresented: $showingEditPortfolio) {
            if let portfolio = selectedPortfolio {
                EditPortfolioView(
                    portfolio: portfolio,
                    portfolioManager: portfolioManager
                )
            }
        }
    }

}

struct PortfolioRowView: View {
    let portfolio: Portfolio
    let isSelected: Bool
    @ObservedObject var portfolioManager: PortfolioManager
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    // Actions
    // @Binding var showingExportOptions: Bool - Removed in favor of closure

    @State private var showingDeleteAlert = false
    @State private var isDarkMode = false

    var body: some View {
        HStack(spacing: 12) {
            // Portfolio Icon
            Image(systemName: portfolio.color.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(portfolio.color.color.opacity(0.3))
                )

            // Portfolio Info
            VStack(alignment: .leading, spacing: 4) {
                Text(portfolio.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Created: \(portfolio.createdAt, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.6))
            }

            Spacer()

            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#7C4DFF"))
            }

            // Action Menu
            Menu {
                // Export
                Button(action: onExport) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Divider()

                // Edit
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                // Delete
                if portfolioManager.canDeletePortfolio(portfolio) {
                    Button(
                        role: .destructive,
                        action: {
                            showingDeleteAlert = true
                        }
                    ) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1B2142"), Color(hex: "#262D52")],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isSelected ? Color(hex: "#7C4DFF") : Color.white.opacity(0.08), lineWidth: 1)
        )
        .onTapGesture {
            if !isSelected {
                portfolioManager.switchToPortfolio(portfolio)
            }
        }
        .alert("Delete Portfolio", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text(
                "Are you sure you want to delete portfolio '\(portfolio.name)'? This action cannot be undone."
            )
        }
        .onAppear {
            isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

struct PortfolioMenuView: View {
    @ObservedObject var portfolioManager: PortfolioManager
    @Binding var showingEditPortfolio: Bool
    @Binding var selectedPortfolio: Portfolio?

    // Actions from Parent
    @Binding var showingExportOptions: Bool
    @Binding var showingRealtimePrices: Bool
    @Binding var isHidden: Bool
    @Binding var showingAddPortfolio: Bool

    @Environment(\.presentationMode) private var presentationMode
    @State private var isDarkMode = false
    @State private var menuErrorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#050B1F"), Color(hex: "#111736"), Color(hex: "#0A1128")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "#7C4DFF"))
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 80, height: 80)
                                )

                            Text("Portfolio Management")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text("Manage your portfolios")
                                .font(.subheadline)
                                .foregroundColor(Color.white.opacity(0.6))

                            Text("\(portfolioManager.portfolios.count) / 5 portfolios")
                                .font(.footnote)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .padding(.top, 20)

                        // Create New Portfolio Button
                        Button(action: {
                            showingAddPortfolio = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Create New Portfolio")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#4F46E5"), Color(hex: "#4338CA")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        // Portfolio List
                        LazyVStack(spacing: 12) {
                            ForEach(portfolioManager.portfolios) { portfolio in
                                PortfolioRowView(
                                    portfolio: portfolio,
                                    isSelected: portfolio.id == portfolioManager.currentPortfolioId,
                                    portfolioManager: portfolioManager,
                                    onEdit: {
                                        presentationMode.wrappedValue.dismiss()
                                        // Delay to allow menu to dismiss before showing edit sheet
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            selectedPortfolio = portfolio
                                            showingEditPortfolio = true
                                        }
                                    },
                                    onDelete: {
                                        guard portfolioManager.canDeletePortfolio(portfolio) else {
                                            menuErrorMessage =
                                                PortfolioManager.PortfolioError.minLimitReached
                                                .errorDescription
                                                ?? "You must have at least one portfolio."
                                            showingErrorAlert = true
                                            return
                                        }

                                        do {
                                            try portfolioManager.deletePortfolio(portfolio)
                                        } catch {
                                            menuErrorMessage =
                                                (error as? LocalizedError)?.errorDescription
                                                ?? error.localizedDescription
                                            showingErrorAlert = true
                                        }
                                    },
                                    onExport: {
                                        presentationMode.wrappedValue.dismiss()
                                        // Delay to allow menu to dismiss before showing export sheet
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showingExportOptions = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Operation Failed"),
                message: Text(menuErrorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }

    }
}

// MARK: - Minimal placeholders to satisfy compiler
private enum PortfolioSheetColors {
    static let backgroundTop = Color(hex: "#050B1F")
    static let backgroundBottom = Color(hex: "#0F1431")
    static let cardTop = Color(hex: "#1F2446")
    static let cardBottom = Color(hex: "#121530")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let border = Color.white.opacity(0.12)
}

struct AddPortfolioView: View {
    @ObservedObject var portfolioManager: PortfolioManager
    @Environment(\.presentationMode) private var presentationMode
    @State private var name: String = ""
    @State private var selectedColor: PortfolioColor = .blue
    @State private var errorMessage: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && portfolioManager.canAddPortfolio }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        PortfolioSheetColors.backgroundTop, PortfolioSheetColors.backgroundBottom,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create New Portfolio")
                                .font(.title3.bold())
                                .foregroundColor(PortfolioSheetColors.textPrimary)
                            Text(
                                "Set a portfolio name and choose a color. Assets for each portfolio are stored independently."
                            )
                            .font(.callout)
                            .foregroundColor(PortfolioSheetColors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Portfolio Name")
                                .font(.headline)
                                .foregroundColor(PortfolioSheetColors.textPrimary)
                            TextField("E.g. Long Term", text: $name)
                                .padding()
                                .foregroundColor(PortfolioSheetColors.textPrimary)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            PortfolioSheetColors.cardTop,
                                            PortfolioSheetColors.cardBottom,
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PortfolioSheetColors.border, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Theme Color")
                                .font(.headline)
                                .foregroundColor(PortfolioSheetColors.textPrimary)

                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: 12), count: 4),
                                spacing: 12
                            ) {
                                ForEach(PortfolioColor.allCases, id: \.self) { color in
                                    colorOption(for: color)
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                "You can create up to 5 portfolios", systemImage: "info.circle"
                            )
                            .font(.footnote)
                            .foregroundColor(PortfolioSheetColors.textSecondary)
                            if !portfolioManager.canAddPortfolio {
                                Text(
                                    "Portfolio limit reached. Delete an existing portfolio to create a new one."
                                )
                                .font(.footnote)
                                .foregroundColor(.orange)
                            }
                        }

                        Button {
                            do {
                                let portfolio = try portfolioManager.addPortfolio(
                                    name: trimmedName, color: selectedColor)
                                portfolioManager.switchToPortfolio(portfolio)
                                presentationMode.wrappedValue.dismiss()
                            } catch {
                                errorMessage =
                                    (error as? LocalizedError)?.errorDescription
                                    ?? error.localizedDescription
                            }
                        } label: {
                            Text("Create Portfolio")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            canSave
                                                ? LinearGradient(
                                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                                : LinearGradient(
                                                    colors: [
                                                        Color.gray.opacity(0.6),
                                                        Color.gray.opacity(0.4),
                                                    ], startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PortfolioSheetColors.border, lineWidth: 1)
                                )
                        }
                        .disabled(!canSave)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Add Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onAppear {
            if !portfolioManager.canAddPortfolio {
                errorMessage = PortfolioManager.PortfolioError.maxLimitReached.errorDescription
            }
        }
    }

    @ViewBuilder
    private func colorOption(for color: PortfolioColor) -> some View {
        Button {
            selectedColor = color
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(color.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .opacity(selectedColor == color ? 1 : 0)
                    )
                Text(color.localizedName)
                    .font(.caption)
                    .foregroundColor(PortfolioSheetColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [PortfolioSheetColors.cardTop, PortfolioSheetColors.cardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selectedColor == color ? color.color : PortfolioSheetColors.border,
                        lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EditPortfolioView: View {
    let portfolio: Portfolio
    @ObservedObject var portfolioManager: PortfolioManager
    @Environment(\.presentationMode) private var presentationMode
    @State private var name: String = ""
    @State private var selectedColor: PortfolioColor = .blue
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    func colorOption(for color: PortfolioColor) -> some View {
        Button {
            selectedColor = color
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(color.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .opacity(selectedColor == color ? 1 : 0)
                    )
                Text(color.localizedName)
                    .font(.caption)
                    .foregroundColor(PortfolioSheetColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [PortfolioSheetColors.cardTop, PortfolioSheetColors.cardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selectedColor == color ? color.color : PortfolioSheetColors.border,
                        lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        PortfolioSheetColors.backgroundTop, PortfolioSheetColors.backgroundBottom,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Portfolio Information")
                                .font(.title3.bold())
                                .foregroundColor(PortfolioSheetColors.textPrimary)
                            Text(
                                "Update portfolio name and choose a theme. Changes reflect immediately."
                            )
                            .font(.callout)
                            .foregroundColor(PortfolioSheetColors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Portfolio Name")
                                .font(.headline)
                                .foregroundColor(PortfolioSheetColors.textPrimary)
                            TextField("Portfolio name", text: $name)
                                .padding()
                                .foregroundColor(PortfolioSheetColors.textPrimary)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            PortfolioSheetColors.cardTop,
                                            PortfolioSheetColors.cardBottom,
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PortfolioSheetColors.border, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Theme Color")
                                .font(.headline)
                                .foregroundColor(PortfolioSheetColors.textPrimary)

                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: 12), count: 4),
                                spacing: 12
                            ) {
                                ForEach(PortfolioColor.allCases, id: \.self) { color in
                                    colorOption(for: color)
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }

                        Button {
                            withAnimation {
                                showDeleteAlert = true
                            }
                        } label: {
                            Label("Delete Portfolio", systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.red)
                                .background(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.25), Color.red.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .disabled(!portfolioManager.canDeletePortfolio(portfolio))
                        .opacity(portfolioManager.canDeletePortfolio(portfolio) ? 1 : 0.4)

                        Button {
                            var updated = portfolio
                            updated.name = trimmedName
                            updated.color = selectedColor
                            portfolioManager.updatePortfolio(updated)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            canSave
                                                ? LinearGradient(
                                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                                : LinearGradient(
                                                    colors: [
                                                        Color.gray.opacity(0.6),
                                                        Color.gray.opacity(0.4),
                                                    ], startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PortfolioSheetColors.border, lineWidth: 1)
                                )
                        }
                        .disabled(!canSave)
                    }
                    .padding(24)
                    .navigationTitle("Edit Portfolio")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { presentationMode.wrappedValue.dismiss() }
                        }
                    }
                    .alert(isPresented: $showDeleteAlert) {
                        Alert(
                            title: Text("Delete Portfolio"),
                            message: Text(
                                "Are you sure you want to delete portfolio '\(portfolio.name)'? This action will permanently remove all data associated with it."
                            ),
                            primaryButton: .destructive(Text("Delete")) {
                                do {
                                    try portfolioManager.deletePortfolio(portfolio)
                                    portfolioManager.clearPortfolioData(for: portfolio.id)
                                    presentationMode.wrappedValue.dismiss()
                                } catch {
                                    errorMessage =
                                        (error as? LocalizedError)?.errorDescription
                                        ?? error.localizedDescription
                                }
                            },
                            secondaryButton: .cancel(Text("İptal"))
                        )
                    }
                }
                .onAppear {
                    name = portfolio.name
                    selectedColor = portfolio.color
                }
            }

        }

    }
}

#Preview {
    PortfolioHeader(
        portfolioManager: PortfolioManager(),
        showingExportOptions: .constant(false),
        showingRealtimePrices: .constant(false),
        isHidden: .constant(false)
    )
}
