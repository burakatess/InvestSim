import SwiftUI

struct TemplateSaveSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Template Name")
                    .font(.headline)
                TextField("E.g: Balanced BTC/GOLD", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Spacer()
                Button("Save") {
                    onSave(name)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Save Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }
}
