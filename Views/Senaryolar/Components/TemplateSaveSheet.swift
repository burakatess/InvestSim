import SwiftUI

struct TemplateSaveSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ScenarioDesign.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Şablon Adı")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ScenarioDesign.textPrimary)

                    TextField(
                        "", text: $name,
                        prompt: Text("Örn: BTC/Altın Dengeli").foregroundColor(
                            ScenarioDesign.textPlaceholder)
                    )
                    .font(.system(size: 16))
                    .foregroundColor(ScenarioDesign.textPrimary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)

                    Spacer()

                    ScenarioGradientButton(title: "Kaydet", icon: "square.and.arrow.down") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .opacity(name.isEmpty ? 0.5 : 1)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Şablon Kaydet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(ScenarioDesign.textSecondary)
                }
            }
        }
    }
}
