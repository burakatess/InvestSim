import SwiftUI

private enum AssetSheetColors {
    static let backgroundTop = Color(hex: "#050B1F")
    static let backgroundBottom = Color(hex: "#0F1431")
    static let cardTop = Color(hex: "#1F2446")
    static let cardBottom = Color(hex: "#121530")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let accent = Color(hex: "#7C83FF")
    static let success = Color(hex: "#20C997")
    static let border = Color.white.opacity(0.15)
}

struct AddAssetSheet: View {
    @ObservedObject var viewModel: DashboardVM
    @Environment(\.presentationMode) private var presentationMode

    @State private var showPicker = false
    @State private var pickerCategory: AssetCategory = .crypto
    @State private var assetForms: [AssetForm] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var inputValidationMessage: String?
    @State private var isSubmitting = false

    private let assetHelper = AssetSelectionHelper.shared

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AssetSheetColors.backgroundTop, AssetSheetColors.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        assetSelectionSection

                        if let inputValidationMessage {
                            Text(inputValidationMessage)
                                .font(.footnote)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }

                        actionButtons
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPicker) {
            MultiSelectAssetPicker(
                selectedCategory: $pickerCategory,
                preselected: Set(assetForms.map(\.asset)),
                onConfirm: { codes in
                    updateSelection(with: codes)
                }
            )
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(isSuccess ? "Success" : "Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if isSuccess {
                        assetForms.removeAll()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AssetSheetColors.success)
                .background(
                    Circle()
                        .fill(AssetSheetColors.success.opacity(0.18))
                        .frame(width: 80, height: 80)
                )

            Text("Add New Asset")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AssetSheetColors.textPrimary)

            Text("Add new investments to your portfolio")
                .font(.subheadline)
                .foregroundColor(AssetSheetColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var assetSelectionSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Amount")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AssetSheetColors.textPrimary)

                Button(action: { showPicker = true }) {
                    selectionButtonLabel
                }
                .buttonStyle(PlainButtonStyle())

                if assetForms.isEmpty {
                    Text(
                        "You can select multiple assets and enter quantity and price for each."
                    )
                    .font(.footnote)
                    .foregroundColor(AssetSheetColors.textSecondary)
                    .padding(.horizontal, 4)
                }
            }

            ForEach($assetForms) { $form in
                assetFormCard(form: $form)
            }
        }
        .padding(.horizontal, 20)
    }

    private var selectionButtonLabel: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(assetForms.isEmpty ? "Select asset" : assetSummaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AssetSheetColors.textPrimary)
                if !assetForms.isEmpty {
                    Text(assetSummarySubtitle)
                        .font(.caption)
                        .foregroundColor(AssetSheetColors.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(AssetSheetColors.textSecondary)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AssetSheetColors.border, lineWidth: 1)
        )
    }

    private func assetFormCard(form: Binding<AssetForm>) -> some View {
        let asset = form.wrappedValue.asset
        let quantityBinding = Binding<String>(
            get: { form.wrappedValue.quantity },
            set: { newValue in
                form.wrappedValue.quantity = sanitizeNumericInput(newValue)
            }
        )
        let unitPriceBinding = Binding<String>(
            get: { form.wrappedValue.unitPrice },
            set: { newValue in
                form.wrappedValue.unitPrice = sanitizeNumericInput(newValue)
            }
        )

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.displayName)
                        .font(.headline)
                        .foregroundColor(AssetSheetColors.textPrimary)
                    Text(asset.symbol)
                        .font(.subheadline)
                        .foregroundColor(AssetSheetColors.textSecondary)
                }
                Spacer()
                Button(action: { removeAsset(asset) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AssetSheetColors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(Text("Remove \(asset.displayName)"))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Quantity")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AssetSheetColors.textPrimary)

                HStack {
                    TextField(
                        "0,00",
                        text: quantityBinding,
                        prompt: Text("0,00").foregroundColor(Color(hex: "#A9A9A9"))
                    )
                    .keyboardType(.decimalPad)
                    .font(.body)
                    .foregroundColor(AssetSheetColors.textPrimary)

                    Text("Quantity")
                        .font(.subheadline)
                        .foregroundColor(AssetSheetColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AssetSheetColors.border, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Unit Price")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AssetSheetColors.textPrimary)

                HStack(spacing: 8) {
                    Text("$")
                        .font(.body)
                        .foregroundColor(AssetSheetColors.textSecondary)

                    TextField(
                        "0,00",
                        text: unitPriceBinding,
                        prompt: Text("0,00").foregroundColor(Color(hex: "#A9A9A9"))
                    )
                    .keyboardType(.decimalPad)
                    .font(.body)
                    .foregroundColor(AssetSheetColors.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AssetSheetColors.border, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Purchase Date")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AssetSheetColors.textPrimary)

                DatePicker("", selection: form.date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AssetSheetColors.border, lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AssetSheetColors.cardTop.opacity(0.7), AssetSheetColors.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AssetSheetColors.border, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: addAsset) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Text(addButtonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.leading, isSubmitting ? 4 : 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AssetSheetColors.success, AssetSheetColors.success.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(
                    color: Color.green.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSubmit || isSubmitting)
            .opacity((!canSubmit || isSubmitting) ? 0.6 : 1.0)

            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AssetSheetColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AssetSheetColors.border, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
    }

    private var addButtonTitle: String {
        switch assetForms.count {
        case 0: return "Add Asset"
        case 1: return "Add Asset"
        default: return "Add Assets"
        }
    }

    private var assetSummaryTitle: String {
        if assetForms.count == 1 {
            return assetForms.first?.asset.displayName ?? "Select asset"
        }
        return "\(assetForms.count) assets selected"
    }

    private var assetSummarySubtitle: String {
        let names = assetForms.map { $0.asset.displayName }
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return names.joined(separator: ", ")
        default:
            let prefix = names.prefix(2).joined(separator: ", ")
            return "\(prefix) +\(names.count - 2)"
        }
    }

    private var canSubmit: Bool {
        !assetForms.isEmpty
            && assetForms.allSatisfy { !$0.quantity.isEmpty && !$0.unitPrice.isEmpty }
    }

    private func addAsset() {
        guard !assetForms.isEmpty else {
            isSuccess = false
            alertMessage = "Please select at least one asset."
            showingAlert = true
            return
        }

        var parsedForms: [(AssetForm, Double, Double)] = []

        for form in assetForms {
            let sanitizedQuantity = form.quantity.replacingOccurrences(of: ",", with: ".")
            guard let quantityValue = Double(sanitizedQuantity), quantityValue > 0 else {
                isSuccess = false
                alertMessage = "Please enter a valid quantity for \(form.asset.displayName)."
                showingAlert = true
                return
            }

            let sanitizedPrice = form.unitPrice.replacingOccurrences(of: ",", with: ".")
            guard let priceValue = Double(sanitizedPrice), priceValue > 0 else {
                isSuccess = false
                alertMessage = "Please enter a valid unit price for \(form.asset.displayName)."
                showingAlert = true
                return
            }

            parsedForms.append((form, quantityValue, priceValue))
        }

        inputValidationMessage = nil
        isSubmitting = true

        Task {
            defer {
                Task { @MainActor in isSubmitting = false }
            }

            for entry in parsedForms {
                await viewModel.addAsset(
                    asset: entry.0.asset,
                    quantity: entry.1,
                    unitPrice: entry.2,
                    date: entry.0.date
                )
            }

            await MainActor.run {
                alertMessage =
                    parsedForms.count == 1
                    ? "Asset added successfully!"
                    : "\(parsedForms.count) assets added successfully!"
                isSuccess = true
                showingAlert = true
            }
        }
    }

    private func updateSelection(with codes: [AssetCode]) {
        var seen = Set<AssetCode>()
        let uniqueCodes = codes.compactMap { code -> AssetCode? in
            guard !seen.contains(code) else { return nil }
            seen.insert(code)
            return code
        }

        let sortedCodes = uniqueCodes.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        var updated: [AssetForm] = []
        for code in sortedCodes {
            if let existing = assetForms.first(where: { $0.asset == code }) {
                updated.append(existing)
            } else {
                updated.append(AssetForm(asset: code))
            }
        }

        assetForms = updated
    }

    private func removeAsset(_ asset: AssetCode) {
        assetForms.removeAll { $0.asset == asset }
    }

    private func sanitizeNumericInput(_ newValue: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789,")
        var scalars = newValue.unicodeScalars.filter { allowedCharacters.contains($0) }
        var sanitized = String(String.UnicodeScalarView(scalars))

        let commaIndices = sanitized.indices.filter { sanitized[$0] == "," }
        if commaIndices.count > 1 {
            for index in commaIndices.dropFirst().reversed() {
                sanitized.remove(at: index)
            }
        }

        if sanitized.count > 12 {
            sanitized = String(sanitized.prefix(12))
        }

        if sanitized != newValue {
            inputValidationMessage = "Please enter numbers only."
        } else {
            inputValidationMessage = nil
        }

        return sanitized
    }
}

extension AddAssetSheet {
    fileprivate struct AssetForm: Identifiable, Equatable {
        let id = UUID()
        let asset: AssetCode
        var quantity: String
        var unitPrice: String
        var date: Date

        init(asset: AssetCode) {
            self.asset = asset
            self.quantity = ""
            self.unitPrice = ""
            self.date = Date()
        }
    }
}

struct MultiSelectAssetPicker: View {
    @Binding var selectedCategory: AssetCategory
    let preselected: Set<AssetCode>
    let onConfirm: ([AssetCode]) -> Void

    @Environment(\.presentationMode) private var presentationMode

    private let helper = AssetSelectionHelper.shared
    @State private var searchText: String = ""
    @State private var pendingSelection: Set<AssetCode> = []

    private var availableCategories: [AssetCategory] {
        AssetCategory.allCases
    }

    private var filteredAssets: [SelectableAsset] {
        let assets = helper.getAssetsByCategory(selectedCategory)
        guard !searchText.isEmpty else { return assets }
        let query = searchText.lowercased()
        return assets.filter { asset in
            asset.displayName.lowercased().contains(query)
                || asset.symbol.lowercased().contains(query)
        }
    }

    private var selectionHint: String {
        switch pendingSelection.count {
        case 0: return "No assets selected"
        case 1: return "1 asset selected"
        default: return "\(pendingSelection.count) assets selected"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(availableCategories, id: \.self) { category in
                        Label(category.displayName, systemImage: category.icon).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .onAppear {
                    if !availableCategories.contains(selectedCategory) {
                        selectedCategory = availableCategories.first ?? .crypto
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search assets...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AssetSheetColors.border, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Text(selectionHint)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AssetSheetColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredAssets) { asset in
                            let isSelected = pendingSelection.contains(asset.assetCode)
                            Button {
                                if isSelected {
                                    pendingSelection.remove(asset.assetCode)
                                } else {
                                    pendingSelection.insert(asset.assetCode)
                                }
                            } label: {
                                AssetMultiSelectRow(asset: asset, isSelected: isSelected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .background(Color.clear)
            }
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [AssetSheetColors.backgroundTop, AssetSheetColors.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Add Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        confirmSelection()
                    }
                    .disabled(pendingSelection.isEmpty)
                }
            }
            .onAppear {
                pendingSelection = preselected
            }
        }
    }

    private func confirmSelection() {
        let sortedSelection = pendingSelection.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        onConfirm(sortedSelection)
        presentationMode.wrappedValue.dismiss()
    }
}

private struct AssetMultiSelectRow: View {
    let asset: SelectableAsset
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundColor(AssetSheetColors.textPrimary)
                Text(asset.symbol)
                    .font(.caption)
                    .foregroundColor(AssetSheetColors.textSecondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(
                    isSelected ? AssetSheetColors.accent : AssetSheetColors.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [AssetSheetColors.cardTop, AssetSheetColors.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? AssetSheetColors.accent.opacity(0.6) : AssetSheetColors.border,
                    lineWidth: 1)
        )
    }
}

#Preview {
    AddAssetSheet(
        viewModel: DashboardVM(
            container: AppContainer(mockMode: true), portfolioManager: PortfolioManager()))
}
