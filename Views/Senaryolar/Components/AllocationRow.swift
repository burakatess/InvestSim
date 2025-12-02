import SwiftUI

struct AllocationRow: View {
    @ObservedObject var allocation: AssetAllocation
    let onChange: (Decimal) -> Void
    let onRemove: () -> Void

    @State private var percentText: String = ""
    private static let formatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "en_US")
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        return nf
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primaryBlue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: allocation.assetCode.fallbackIcon)
                        .foregroundColor(.primaryBlue)
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(truncatedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(allocation.assetCode.symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 130, alignment: .leading)

            Slider(
                value: Binding<Double>(
                    get: { (allocation.weight * 100).doubleValue },
                    set: { value in
                        let clamped = max(0, min(100, value))
                        percentText = Self.formatter.string(from: NSNumber(value: clamped)) ?? String(format: "%.1f", clamped)
                        onChange(Decimal(clamped) / 100)
                    }
                ),
                in: 0...100,
                step: 0.5
            )
            .frame(width: 115)
            .tint(.primaryBlue)

            HStack(spacing: 4) {
                TextField("0", text: $percentText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 38)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primaryBlue.opacity(0.25), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                    )
                    .onChange(of: percentText) { _, newValue in
                        handleTextChange(newValue)
                    }
                Text("%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red.opacity(0.75))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.08))
                    )
            }
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            percentText = formattedPercent
        }
        .onChange(of: allocation.weight) { _, _ in
            percentText = formattedPercent
        }
    }

    private var formattedPercent: String {
        let val = (allocation.weight * 100).doubleValue
        return Self.formatter.string(from: NSNumber(value: val)) ?? String(format: "%.1f", val)
    }

    private var truncatedName: String {
        let name = allocation.assetCode.displayName
        let maxCount = 11
        guard name.count > maxCount else { return name }
        let prefix = name.prefix(maxCount - 1)
        return prefix + "…"
    }

    private func handleTextChange(_ newValue: String) {
        let sanitized = sanitizeInput(newValue)
        if sanitized != newValue {
            percentText = sanitized
        }

        guard !sanitized.isEmpty else {
            onChange(0)
            return
        }

        if sanitized.last == "," {
            return
        }

        let normalized = sanitized.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) {
            let clamped = max(0, min(100, value))
            onChange(Decimal(clamped) / 100)
        }
    }

    private func sanitizeInput(_ input: String) -> String {
        let allowed = CharacterSet(charactersIn: "0123456789,")
        var filteredScalars = input.unicodeScalars.filter { allowed.contains($0) }
        var sanitized = String(String.UnicodeScalarView(filteredScalars))

        let commaIndices = sanitized.indices.filter { sanitized[$0] == "," }
        if commaIndices.count > 1 {
            for index in commaIndices.dropFirst().reversed() {
                sanitized.remove(at: index)
            }
        }

        if sanitized.count > 6 {
            sanitized = String(sanitized.prefix(6))
        }

        return sanitized
    }
}
