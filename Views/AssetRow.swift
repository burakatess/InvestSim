import Combine
import SwiftUI
import UIKit

struct AssetRow: View {
    let asset: UserAsset
    let isHidden: Bool
    let onTap: () -> Void
    let isUpdating: Bool = false  // Default value, can be passed from parent

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Sol: Logo ve Varlık Bilgileri
                HStack(spacing: 12) {
                    // Varlık Logosu (Geçici Test)
                    assetImage

                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.asset.rawValue)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("\(String(format: "%.2f", asset.quantity)) \(asset.asset.rawValue)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Sağ: Değer ve Değişim
                VStack(alignment: .trailing, spacing: 4) {
                    if isUpdating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))

                            Text("Updating...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(isHidden ? "$••••••••" : formatCurrency(asset.currentValue))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .animation(.easeInOut(duration: 0.3), value: isHidden)

                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(changeColor)

                            Text(
                                isHidden
                                    ? "••% •••"
                                    : "\(String(format: "%.2f", abs(asset.priceChangePercentage)))%"
                            )
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(changeColor)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var assetColor: Color {
        switch asset.asset {
        case .USD, .EUR, .GBP, .JPY, .CHF, .CAD, .AUD, .CNH, .HKD, .NZD:
            return Color.blue
        default:
            return Color.purple
        }
    }

    private var assetIcon: String {
        switch asset.asset {
        case .USD: return "U"
        case .EUR: return "E"
        case .GBP: return "G"
        case .JPY: return "J"
        case .CHF: return "C"
        case .CAD: return "K"
        case .AUD: return "A"
        case .CNH: return "¥"
        case .HKD: return "H"
        case .NZD: return "N"
        default:
            return String(asset.asset.rawValue.prefix(1))
        }
    }

    private var changeColor: Color {
        if asset.priceChange > 0 {
            return Color(hex: "#16A34A")  // Yeşil
        } else if asset.priceChange < 0 {
            return Color(hex: "#DC2626")  // Kırmızı
        } else {
            return Color(hex: "#6B7280")  // Gri
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    @ViewBuilder
    private var assetImage: some View {
        let placeholder = {
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(asset.asset.rawValue.prefix(2))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        if #available(iOS 15.0, *) {
            AsyncImage(url: URL(string: asset.asset.logoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                placeholder()
            }
        } else {
            LegacyAsyncImage(url: URL(string: asset.asset.logoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                placeholder()
            }
        }
    }
}

private struct LegacyAsyncImage<Content: View, Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    init(
        url: URL?, @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(from: url)
        }
    }
}

private final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    // Static cache - t\u00fcm ImageLoader instance'lar\u0131 aras\u0131nda payla\u015f\u0131l\u0131r
    private static var cache: [URL: UIImage] = [:]
    private static var cacheQueue = DispatchQueue(label: "com.investsimulator.imagecache")

    init() {
        // Memory warning observer - cache'i temizle
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.cacheQueue.async {
                Self.cache.removeAll()
                print("🧹 Image cache cleared (memory warning)")
            }
        }
    }

    func load(from url: URL?) {
        guard let url else { return }

        // \u00d6nce cache'i kontrol et
        Self.cacheQueue.async {
            if let cachedImage = Self.cache[url] {
                DispatchQueue.main.async {
                    self.image = cachedImage
                }
                return
            }

            // Cache'de yoksa indir
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data, let uiImage = UIImage(data: data) {
                    // Cache'e kaydet
                    Self.cacheQueue.async {
                        Self.cache[url] = uiImage
                    }

                    DispatchQueue.main.async {
                        self.image = uiImage
                    }
                }
            }.resume()
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AssetRow(
            asset: UserAsset(
                asset: .USD,
                quantity: 1000.0,
                unitPrice: 32.50,
                purchaseDate: Date(),
                currentPrice: 33.25
            ),
            isHidden: false,
            onTap: {}
        )

        AssetRow(
            asset: UserAsset(
                asset: .BTC,
                quantity: 0.5,
                unitPrice: 45000.0,
                purchaseDate: Date(),
                currentPrice: 46000.0
            ),
            isHidden: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
