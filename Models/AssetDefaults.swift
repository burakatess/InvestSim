import Foundation

struct AssetDefaultItem {
    let code: String
    let displayName: String
    let symbol: String
    let category: String
    let currency: String
    let logoURL: String?
    let providerType: AssetProviderType
    let externalId: String?
    let coingeckoId: String?
    let isActive: Bool

    init(
        code: String, displayName: String, symbol: String, category: String, currency: String,
        logoURL: String?, providerType: AssetProviderType = .unknown, externalId: String? = nil,
        coingeckoId: String? = nil, isActive: Bool = true
    ) {
        self.code = code
        self.displayName = displayName
        self.symbol = symbol
        self.category = category
        self.currency = currency
        self.logoURL = logoURL
        self.providerType = providerType
        self.externalId = externalId
        self.coingeckoId = coingeckoId
        self.isActive = isActive
    }
}

enum AssetDefaults {
    static let all: [AssetDefaultItem] = [
        AssetDefaultItem(
            code: "USD", displayName: "US Dollar", symbol: "USD", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "EUR", displayName: "Euro", symbol: "EUR", category: "forex", currency: "TRY",
            logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "GBP", displayName: "British Pound", symbol: "GBP", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "JPY", displayName: "Japanese Yen", symbol: "JPY", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "AUD", displayName: "Australian Dollar", symbol: "AUD", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "CAD", displayName: "Canadian Dollar", symbol: "CAD", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "CHF", displayName: "Swiss Franc", symbol: "CHF", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "CNH", displayName: "Chinese Yuan (Offshore)", symbol: "CNH", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "HKD", displayName: "Hong Kong Dollar", symbol: "HKD", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),
        AssetDefaultItem(
            code: "NZD", displayName: "New Zealand Dollar", symbol: "NZD", category: "forex",
            currency: "TRY", logoURL: nil, providerType: .tiingo),

        AssetDefaultItem(
            code: "BTC", displayName: "Bitcoin", symbol: "BTC", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "bitcoin"),
        AssetDefaultItem(
            code: "ETH", displayName: "Ethereum", symbol: "ETH", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "ethereum"),
        AssetDefaultItem(
            code: "BNB", displayName: "Binance Coin", symbol: "BNB", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "binancecoin"),
        AssetDefaultItem(
            code: "XRP", displayName: "Ripple", symbol: "XRP", category: "crypto", currency: "USDT",
            logoURL: nil, providerType: .binance, coingeckoId: "ripple"),
        AssetDefaultItem(
            code: "ADA", displayName: "Cardano", symbol: "ADA", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "cardano"),
        AssetDefaultItem(
            code: "DOGE", displayName: "Dogecoin", symbol: "DOGE", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "dogecoin"),
        AssetDefaultItem(
            code: "SOL", displayName: "Solana", symbol: "SOL", category: "crypto", currency: "USDT",
            logoURL: nil, providerType: .binance, coingeckoId: "solana"),
        AssetDefaultItem(
            code: "MATIC", displayName: "Polygon", symbol: "MATIC", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "matic-network"),
        AssetDefaultItem(
            code: "DOT", displayName: "Polkadot", symbol: "DOT", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "polkadot"),
        AssetDefaultItem(
            code: "AVAX", displayName: "Avalanche", symbol: "AVAX", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "avalanche-2"),
        AssetDefaultItem(
            code: "LTC", displayName: "Litecoin", symbol: "LTC", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "litecoin"),
        AssetDefaultItem(
            code: "UNI", displayName: "Uniswap", symbol: "UNI", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "uniswap"),
        AssetDefaultItem(
            code: "LINK", displayName: "Chainlink", symbol: "LINK", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "chainlink"),
        AssetDefaultItem(
            code: "ATOM", displayName: "Cosmos", symbol: "ATOM", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "cosmos"),
        AssetDefaultItem(
            code: "ETC", displayName: "Ethereum Classic", symbol: "ETC", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance,
            coingeckoId: "ethereum-classic"),
        AssetDefaultItem(
            code: "XLM", displayName: "Stellar", symbol: "XLM", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "stellar"),
        AssetDefaultItem(
            code: "ALGO", displayName: "Algorand", symbol: "ALGO", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "algorand"),
        AssetDefaultItem(
            code: "VET", displayName: "VeChain", symbol: "VET", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "vechain"),
        AssetDefaultItem(
            code: "ICP", displayName: "Internet Computer", symbol: "ICP", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance,
            coingeckoId: "internet-computer"),
        AssetDefaultItem(
            code: "FIL", displayName: "Filecoin", symbol: "FIL", category: "crypto",
            currency: "USDT", logoURL: nil, providerType: .binance, coingeckoId: "filecoin"),
    ]

    static let popularCodes: Set<String> = [
        "BTC", "ETH", "BNB", "XRP", "ADA", "SOL", "DOT", "MATIC",
        "USD", "EUR",
    ]
}
