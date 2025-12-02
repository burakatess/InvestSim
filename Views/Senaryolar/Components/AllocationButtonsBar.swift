import SwiftUI

struct AllocationButtonsBar: View {
    let isDisabled: Bool
    let onEqualize: () -> Void
    let onSpread: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Distribute Equally", action: onEqualize)
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(isDisabled)
            Button("Spread Remaining", action: onSpread)
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(isDisabled)
            Button("Reset", action: onReset)
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(isDisabled)
        }
    }
}
