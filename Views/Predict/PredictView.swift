import SwiftUI

struct PredictView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#050B1F").ignoresSafeArea()

                VStack {
                    Text("Predict")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Future prediction features coming soon.")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Predict")
        }
    }
}
