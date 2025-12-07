import SwiftUI

struct AllocationButtonsBar: View {
    let isDisabled: Bool
    let onEqualize: () -> Void
    let onSpread: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Eşitle", action: onEqualize)
                .buttonStyle(.bordered)
                .tint(ScenarioDesign.accentCyan)
                .frame(maxWidth: .infinity)
                .disabled(isDisabled)
            Button("Dağıt", action: onSpread)
                .buttonStyle(.bordered)
                .tint(ScenarioDesign.accentCyan)
                .frame(maxWidth: .infinity)
                .disabled(isDisabled)
            Button("Sıfırla", action: onReset)
                .buttonStyle(.bordered)
                .tint(ScenarioDesign.accentCyan)
                .frame(maxWidth: .infinity)
                .disabled(isDisabled)
        }
    }
}
