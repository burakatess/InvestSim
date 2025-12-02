import SwiftUI

struct DayPickerSheet: View {
    let maxSelection: Int
    let initialSelection: [Int]
    let onDone: ([Int]) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var selection: Set<Int> = []

    init(maxSelection: Int, initialSelection: [Int], onDone: @escaping ([Int]) -> Void) {
        self.maxSelection = maxSelection
        self.initialSelection = initialSelection
        self.onDone = onDone
        _selection = State(initialValue: Set(initialSelection))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Select Days of Month")
                    .font(.headline)
                    .padding(.top, 12)

                // 7 sütunlu mini takvim grid (1..30)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                    spacing: 8
                ) {
                    ForEach(1...30, id: \.self) { day in
                        Button(action: { toggle(day) }) {
                            Text("\(day)")
                                .font(.body)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    selection.contains(day) ? Color.blue : Color(.systemGray6)
                                )
                                .foregroundColor(selection.contains(day) ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .disabled(!selection.contains(day) && selection.count >= maxSelection)
                    }
                }
                .padding(.horizontal)

                Text("Selection: \(selection.sorted().map(String.init).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone(Array(selection))
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selection.count != maxSelection)
                }
            }
        }
    }

    private func toggle(_ day: Int) {
        if selection.contains(day) {
            selection.remove(day)
        } else if selection.count < maxSelection {
            selection.insert(day)
        }
    }
}
