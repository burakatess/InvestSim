import Foundation

struct CoinGeckoMarketCoin: Decodable {
    let id: String
    let symbol: String
    let name: String
}

@MainActor
final class CoinGeckoAssetSyncService {
    private let repository: AssetRepository
    private let session: URLSession
    private let baseURL = URL(string: "https://api.coingecko.com/api/v3/coins/markets")!

    init(repository: AssetRepository, session: URLSession = .shared) {
        self.repository = repository
        self.session = session
    }

    func syncTopCoins(limit: Int = 100) async throws {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: String(limit)),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "false"),
        ]
        guard let url = components.url else { return }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
        let coins = try JSONDecoder().decode([CoinGeckoMarketCoin].self, from: data)
        for coin in coins {
            let code = coin.symbol.uppercased()
            guard !code.isEmpty else { continue }
            let dto = AssetDTO(
                code: code,
                displayName: coin.name,
                symbol: code,
                category: AssetType.crypto.rawValue,
                currency: "USD",
                logoURL: nil,
                isActive: true,
                providerType: .coingecko,
                externalId: nil,
                coingeckoId: coin.id
            )
            repository.addOrUpdate(from: dto)
        }
    }
}
