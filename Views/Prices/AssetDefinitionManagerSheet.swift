import SwiftUI

struct AssetDefinitionManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssetManagementViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: AssetManagementViewModel(
                repository: container.assetRepository,
                seeder: container.assetSeeder,
                syncService: container.assetSyncService
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    assetForm
                    managementActions
                    feedbackSection
                    existingAssetsSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Asset Definition")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var assetForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add New Asset")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("Code (e.g. AAPL)", text: $viewModel.code)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .padding()
                    .background(formFieldBackground)

                TextField("Asset Name", text: $viewModel.displayName)
                    .padding()
                    .background(formFieldBackground)

                TextField("Symbol (optional)", text: $viewModel.symbol)
                    .textInputAutocapitalization(.characters)
                    .padding()
                    .background(formFieldBackground)

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(AssetCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Currency (e.g. USD)", text: $viewModel.currency)
                    .textInputAutocapitalization(.characters)
                    .padding()
                    .background(formFieldBackground)

                TextField("Logo URL (optional)", text: $viewModel.logoURL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding()
                    .background(formFieldBackground)

                if selectedCategoryRequiresCoinGeckoID {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("CoinGecko ID", text: $viewModel.coingeckoIdentifier)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding()
                            .background(formFieldBackground)
                        Text("This field is required for initial data download.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                TextField("External ID (optional)", text: $viewModel.externalId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding()
                    .background(formFieldBackground)

                Toggle("Active", isOn: $viewModel.isActive)
            }

            Button(action: viewModel.saveAssetDefinition) {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canSave ? Color.primaryBlue : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canSave)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private var managementActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bulk Actions")
                .font(.headline)

            Button {
                viewModel.importDefaultAssets()
            } label: {
                Label("Refresh Data (Force Sync)", systemImage: "arrow.clockwise.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                Task { await viewModel.syncFromCoinGecko() }
            } label: {
                Label("Update CoinGecko List", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isSyncing ? Color.gray.opacity(0.3) : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.isSyncing)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private var feedbackSection: some View {
        VStack(spacing: 8) {
            if let success = viewModel.successMessage {
                feedbackLabel(success, color: .green)
            }
            if let error = viewModel.errorMessage {
                feedbackLabel(error, color: .red)
            }
        }
    }

    private func feedbackLabel(_ message: String, color: Color) -> some View {
        HStack {
            Image(
                systemName: color == .green
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundColor(color)
            Text(message)
                .font(.subheadline)
                .foregroundColor(color)
            Spacer()
        }
        .padding()
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var existingAssetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Assets")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.assets.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if viewModel.assets.isEmpty {
                Text("No assets registered yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.assets) { asset in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(asset.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(asset.code)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(categoryTitle(for: asset))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let id = asset.coingeckoId, !id.isEmpty {
                                Text("CoinGecko ID: \(id)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let symbol = asset.symbol {
                                Text(symbol)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private var formFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
    }

    private func categoryTitle(for asset: AssetDefinition) -> String {
        let normalized = asset.category.lowercased()
        return AssetCategory(rawValue: normalized)?.displayName ?? asset.category.capitalized
    }

    private var selectedCategoryRequiresCoinGeckoID: Bool {
        viewModel.selectedCategory == .crypto
    }
}

#Preview {
    AssetDefinitionManagerSheet(container: AppContainer(mockMode: true))
}
