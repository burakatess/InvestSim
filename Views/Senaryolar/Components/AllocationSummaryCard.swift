import SwiftUI

struct AllocationSummaryCard: View {
    let totalPercent: Double  // 0..100

    private var status: (message: String?, color: Color, progress: Double, displayTotal: Double) {
        guard !totalPercent.isNaN else { return ("No allocation", .gray, 0, 0) }

        let clampedTotal = min(max(totalPercent, 0), 120)
        let roundedTotal = (clampedTotal * 10).rounded() / 10

        if roundedTotal <= 100 {
            let progress = min(1, max(0, roundedTotal / 100))
            if abs(roundedTotal - 100) < 0.05 {
                return (nil, .green, 1, 100)
            } else {
                let missingRaw = max(0, 100 - clampedTotal)
                let missing = (missingRaw * 10).rounded() / 10
                return (String(format: "Missing: %%.1f", missing), .green, progress, roundedTotal)
            }
        }

        if roundedTotal <= 110 {
            let progress = min(1, roundedTotal / 110)
            let excess = ((clampedTotal - 100) * 10).rounded() / 10
            return (String(format: "Exceeded: %%.1f", excess), .yellow, progress, roundedTotal)
        }

        let excess = ((clampedTotal - 100) * 10).rounded() / 10
        return (String(format: "Exceeded: %%.1f", excess), .red, 1, roundedTotal)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Total Allocation")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(status.color)
                        .frame(
                            width: max(
                                8,
                                min(CGFloat(status.progress) * proxy.size.width, proxy.size.width)),
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.25), value: status.progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text(String(format: "%%%.1f", status.displayTotal))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.primary)
                Spacer()
                if let message = status.message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(status.color)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
