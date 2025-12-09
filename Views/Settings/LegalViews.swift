import SwiftUI

// MARK: - Legal Document View
struct LegalDocumentView: View {
    let title: String
    let content: String

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(6)
                    .padding(20)
            }
        }
        .navigationTitle(title)
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

// MARK: - KVKK / GDPR View
struct KVKKGDPRView: View {
    var body: some View {
        LegalDocumentView(
            title: "KVKK / GDPR",
            content: """
                KVKK VE GDPR UYUM POLİTİKASI

                Son Güncelleme: Aralık 2025

                1. VERİ SORUMLUSU

                InvestSimulator uygulaması, kullanıcı verilerinin korunması konusunda 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) ve Avrupa Birliği Genel Veri Koruma Yönetmeliği (GDPR) hükümlerine uygun hareket etmektedir.

                2. TOPLANAN VERİLER

                • Kimlik Bilgileri: Ad, soyad, e-posta adresi
                • Hesap Bilgileri: Kullanıcı adı, profil fotoğrafı
                • Kullanım Verileri: Uygulama içi aktiviteler, tercihler
                • Cihaz Bilgileri: Cihaz modeli, işletim sistemi versiyonu

                3. VERİLERİN İŞLENME AMACI

                • Uygulama hizmetlerinin sunulması
                • Kullanıcı deneyiminin iyileştirilmesi
                • Güvenlik önlemlerinin sağlanması
                • Yasal yükümlülüklerin yerine getirilmesi

                4. VERİLERİN SAKLANMASI

                Verileriniz, hizmet sağladığımız süre boyunca ve yasal zorunluluklar kapsamında güvenli ortamlarda saklanmaktadır.

                5. HAKLARINIZ

                KVKK ve GDPR kapsamında aşağıdaki haklara sahipsiniz:
                • Verilerinize erişim hakkı
                • Verilerin düzeltilmesini talep etme hakkı
                • Verilerin silinmesini talep etme hakkı
                • Veri taşınabilirliği hakkı
                • İşlemeye itiraz hakkı

                6. İLETİŞİM

                Veri koruma ile ilgili sorularınız için:
                privacy@investsimulator.app
                """
        )
    }
}

// MARK: - Terms of Use View
struct TermsOfUseView: View {
    var body: some View {
        LegalDocumentView(
            title: "Terms of Use",
            content: """
                KULLANIM KOŞULLARI

                Son Güncelleme: Aralık 2025

                1. KABUL

                InvestSimulator uygulamasını kullanarak bu koşulları kabul etmiş sayılırsınız.

                2. HİZMET TANIMI

                InvestSimulator, yatırım simülasyonu ve portföy yönetimi araçları sunan bir mobil uygulamadır. Uygulama yalnızca eğitim amaçlıdır ve gerçek yatırım tavsiyesi sunmaz.

                3. KULLANICI SORUMLULUKLARI

                • Hesap bilgilerinizin güvenliğinden siz sorumlusunuz
                • Yasalara uygun kullanım zorunludur
                • Uygulamayı kötüye kullanmak yasaktır

                4. FİKRİ MÜLKİYET

                Tüm içerik, tasarım ve kod InvestSimulator'a aittir. İzinsiz kopyalama ve dağıtım yasaktır.

                5. SORUMLULUK REDDİ

                InvestSimulator finansal tavsiye vermez. Simülasyon sonuçları gerçek yatırım getirisini garanti etmez. Tüm yatırım kararları kullanıcının sorumluluğundadır.

                6. DEĞİŞİKLİKLER

                Bu koşullar önceden bildirimde bulunmaksızın değiştirilebilir. Güncel versiyonu uygulama içinden kontrol edebilirsiniz.

                7. GEÇERLİ HUKUK

                Bu koşullar Türkiye Cumhuriyeti yasalarına tabidir.
                """
        )
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "Privacy Policy",
            content: """
                GİZLİLİK POLİTİKASI

                Son Güncelleme: Aralık 2025

                1. GİRİŞ

                InvestSimulator olarak gizliliğinize saygı duyuyoruz. Bu politika, verilerinizi nasıl topladığımızı, kullandığımızı ve koruduğumuzu açıklar.

                2. TOPLANAN BİLGİLER

                Otomatik Toplanan:
                • Cihaz bilgileri
                • IP adresi
                • Kullanım istatistikleri

                Sizin Sağladığınız:
                • Hesap bilgileri
                • Portföy verileri
                • İletişim bilgileri

                3. BİLGİLERİN KULLANIMI

                Bilgilerinizi şu amaçlarla kullanıyoruz:
                • Hizmet sunumu
                • Güvenlik sağlama
                • Ürün geliştirme
                • Müşteri desteği

                4. VERİ GÜVENLİĞİ

                • End-to-end şifreleme
                • Güvenli veri merkezleri
                • Düzenli güvenlik denetimleri

                5. ÜÇÜNCÜ TARAFLAR

                Verilerinizi pazarlama amaçlı üçüncü taraflarla paylaşmıyoruz. Yalnızca hizmet sağlayıcılarımızla gerekli minimum veri paylaşılır.

                6. ÇEREZLER

                Uygulamamız oturum yönetimi için minimum düzeyde çerez kullanır.

                7. İLETİŞİM

                Gizlilik sorularınız için:
                privacy@investsimulator.app
                """
        )
    }
}

// MARK: - Open Source Licenses View
struct OpenSourceLicensesView: View {
    private let licenses: [(name: String, license: String)] = [
        ("Supabase Swift", "MIT License"),
        ("Google Sign-In", "Apache 2.0"),
        ("Charts", "Apache 2.0"),
        ("Lottie", "Apache 2.0"),
        ("Kingfisher", "MIT License"),
    ]

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(licenses.indices, id: \.self) { index in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(licenses[index].name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)

                                Text(licenses[index].license)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: "doc.text")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Open Source")
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
