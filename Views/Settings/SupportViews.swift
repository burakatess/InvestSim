import MessageUI
import SwiftUI

// MARK: - FAQ View
struct FAQView: View {
    private let faqItems: [(question: String, answer: String)] = [
        (
            "InvestSimulator nedir?",
            "InvestSimulator, yatırım simülasyonu yapmanızı sağlayan bir uygulamadır. Gerçek para riski olmadan portföy yönetimi deneyimi kazanabilirsiniz."
        ),
        (
            "Fiyatlar ne sıklıkla güncellenir?",
            "Kripto para fiyatları anlık olarak, hisse senedi fiyatları piyasa saatlerinde her dakika, forex fiyatları ise 5 dakikada bir güncellenir."
        ),
        (
            "DCA (Dollar Cost Averaging) nedir?",
            "DCA, belirli aralıklarla sabit miktarda yatırım yapma stratejisidir. Bu yöntem, fiyat dalgalanmalarından kaynaklanan riski azaltır."
        ),
        (
            "Portföyüm güvende mi?",
            "Tüm verileriniz şifrelenmiş olarak saklanır. Face ID/Touch ID ile ek güvenlik katmanı ekleyebilirsiniz."
        ),
        (
            "Premium üyelik ne sağlar?",
            "Premium üyelik ile sınırsız portföy, gelişmiş analitik, gerçek zamanlı fiyatlar ve fiyat uyarıları gibi özelliklere erişebilirsiniz."
        ),
    ]

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(faqItems.indices, id: \.self) { index in
                        FAQItemView(
                            question: faqItems[index].question,
                            answer: faqItems[index].answer
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.large)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FAQItemView: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if isExpanded {
                Text(answer)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - User Guide View
struct UserGuideView: View {
    private let guideSteps: [(icon: String, title: String, description: String)] = [
        (
            "chart.line.uptrend.xyaxis",
            "Fiyatları Takip Et",
            "Prices sekmesinden kripto, hisse, forex ve emtia fiyatlarını anlık olarak takip edin."
        ),
        (
            "briefcase.fill",
            "Portföy Oluştur",
            "Portfolio sekmesinden varlıklarınızı ekleyin ve portföy performansınızı izleyin."
        ),
        (
            "waveform.path.ecg",
            "Senaryo Simülasyonu",
            "Scenarios sekmesinden DCA stratejisi veya özel senaryolar oluşturun."
        ),
        (
            "chart.bar.xaxis.ascending",
            "Tahmin Analizi",
            "Predict sekmesinden yapay zeka destekli fiyat tahminlerini görüntüleyin."
        ),
        (
            "gearshape.fill",
            "Ayarları Yapılandır",
            "Settings'den profil, güvenlik ve uygulama tercihlerinizi yönetin."
        ),
    ]

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#7C4DFF"))

                        Text("Kullanım Rehberi")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("InvestSimulator'ı etkili kullanmak için adımlar")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 20)

                    // Steps
                    ForEach(guideSteps.indices, id: \.self) { index in
                        GuideStepView(
                            stepNumber: index + 1,
                            icon: guideSteps[index].icon,
                            title: guideSteps[index].title,
                            description: guideSteps[index].description
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("User Guide")
        .navigationBarTitleDisplayMode(.large)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GuideStepView: View {
    let stepNumber: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#7C4DFF"), Color(hex: "#4CC9F0")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text("\(stepNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#7C4DFF"))

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Report Bug View
struct ReportBugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bugTitle = ""
    @State private var whatHappened = ""
    @State private var stepsToReproduce = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "ant.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#F44336"))

                        Text("Hata Bildir")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)

                    // Form Fields
                    VStack(spacing: 16) {
                        FormField(title: "BAŞLIK", text: $bugTitle, placeholder: "Kısa bir başlık")

                        FormField(
                            title: "NE OLDU?", text: $whatHappened,
                            placeholder: "Karşılaştığınız sorunu açıklayın", isMultiline: true)

                        FormField(
                            title: "TEKRAR ETME ADIMLARI", text: $stepsToReproduce,
                            placeholder: "1. Şunu yaptım\n2. Bunu yaptım", isMultiline: true)

                        // Device Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CİHAZ BİLGİSİ")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.5))

                            Text(deviceInfo)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                    }

                    // Submit Button
                    Button {
                        submitBug()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Gönder")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#7C4DFF"), Color(hex: "#4CC9F0")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(bugTitle.isEmpty || isSubmitting)
                    .opacity(bugTitle.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
        }
        .navigationTitle("Report Bug")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Teşekkürler!", isPresented: $showSuccessAlert) {
            Button("Tamam") { dismiss() }
        } message: {
            Text("Bug raporunuz başarıyla gönderildi.")
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "#0B1120"), Color(hex: "#1A1F3D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var deviceInfo: String {
        let device = UIDevice.current
        return
            """
            Model: \(device.model)
            iOS: \(device.systemVersion)
            App: 2.0.0 (2025.12)
            """
    }

    private func submitBug() {
        isSubmitting = true
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            showSuccessAlert = true
        }
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1)
                .foregroundColor(.white.opacity(0.5))

            if isMultiline {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                    )
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
    }
}

// MARK: - Mail Composer
struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let recipient: String
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void

        init(dismiss: @escaping () -> Void) {
            self.dismiss = { dismiss() }
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}
