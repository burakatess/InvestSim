-- ============================================================================
-- SEED MVP ASSETS (64 Assets)
-- Production-ready asset list with provider mapping
-- ============================================================================

-- Ensure metadata column exists (fix for missing column in 001)
ALTER TABLE assets ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Insert 20 Cryptocurrencies
INSERT INTO assets (symbol, name, type, category, code, provider, provider_id, currency, metadata) VALUES
('BTC', 'Bitcoin', 'crypto', 'crypto', 'BTCUSDT', 'binance', 'BTCUSDT', 'USD', '{"rank": 1, "website": "bitcoin.org"}'),
('ETH', 'Ethereum', 'crypto', 'crypto', 'ETHUSDT', 'binance', 'ETHUSDT', 'USD', '{"rank": 2, "website": "ethereum.org"}'),
('BNB', 'Binance Coin', 'crypto', 'crypto', 'BNBUSDT', 'binance', 'BNBUSDT', 'USD', '{"rank": 4}'),
('SOL', 'Solana', 'crypto', 'crypto', 'SOLUSDT', 'binance', 'SOLUSDT', 'USD', '{"rank": 5}'),
('XRP', 'Ripple', 'crypto', 'crypto', 'XRPUSDT', 'binance', 'XRPUSDT', 'USD', '{"rank": 6}'),
('ADA', 'Cardano', 'crypto', 'crypto', 'ADAUSDT', 'binance', 'ADAUSDT', 'USD', '{"rank": 8}'),
('AVAX', 'Avalanche', 'crypto', 'crypto', 'AVAXUSDT', 'binance', 'AVAXUSDT', 'USD', '{"rank": 9}'),
('DOGE', 'Dogecoin', 'crypto', 'crypto', 'DOGEUSDT', 'binance', 'DOGEUSDT', 'USD', '{"rank": 10}'),
('DOT', 'Polkadot', 'crypto', 'crypto', 'DOTUSDT', 'binance', 'DOTUSDT', 'USD', '{"rank": 11}'),
('MATIC', 'Polygon', 'crypto', 'crypto', 'MATICUSDT', 'binance', 'MATICUSDT', 'USD', '{"rank": 13}'),
('LTC', 'Litecoin', 'crypto', 'crypto', 'LTCUSDT', 'binance', 'LTCUSDT', 'USD', '{"rank": 14}'),
('UNI', 'Uniswap', 'crypto', 'crypto', 'UNIUSDT', 'binance', 'UNIUSDT', 'USD', '{"rank": 16}'),
('ATOM', 'Cosmos', 'crypto', 'crypto', 'ATOMUSDT', 'binance', 'ATOMUSDT', 'USD', '{"rank": 18}'),
('ETC', 'Ethereum Classic', 'crypto', 'crypto', 'ETCUSDT', 'binance', 'ETCUSDT', 'USD', '{"rank": 19}'),
('XLM', 'Stellar', 'crypto', 'crypto', 'XLMUSDT', 'binance', 'XLMUSDT', 'USD', '{"rank": 20}'),
('LINK', 'Chainlink', 'crypto', 'crypto', 'LINKUSDT', 'binance', 'LINKUSDT', 'USD', '{"rank": 21}'),
('ALGO', 'Algorand', 'crypto', 'crypto', 'ALGOUSDT', 'binance', 'ALGOUSDT', 'USD', '{"rank": 25}'),
('VET', 'VeChain', 'crypto', 'crypto', 'VETUSDT', 'binance', 'VETUSDT', 'USD', '{"rank": 28}'),
('ICP', 'Internet Computer', 'crypto', 'crypto', 'ICPUSDT', 'binance', 'ICPUSDT', 'USD', '{"rank": 30}'),
('FIL', 'Filecoin', 'crypto', 'crypto', 'FILUSDT', 'binance', 'FILUSDT', 'USD', '{"rank": 32}')
ON CONFLICT (symbol) DO NOTHING;

-- Insert 20 US Stocks
INSERT INTO assets (symbol, name, type, category, code, provider, provider_id, currency, exchange, sector, metadata) VALUES
('AAPL', 'Apple Inc.', 'stock', 'stock', 'AAPL', 'yahoo', 'AAPL', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 3000000000000}'),
('MSFT', 'Microsoft Corporation', 'stock', 'stock', 'MSFT', 'yahoo', 'MSFT', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 2800000000000}'),
('GOOGL', 'Alphabet Inc.', 'stock', 'stock', 'GOOGL', 'yahoo', 'GOOGL', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 1800000000000}'),
('AMZN', 'Amazon.com Inc.', 'stock', 'stock', 'AMZN', 'yahoo', 'AMZN', 'USD', 'NASDAQ', 'Consumer Cyclical', '{"market_cap": 1700000000000}'),
('NVDA', 'NVIDIA Corporation', 'stock', 'stock', 'NVDA', 'yahoo', 'NVDA', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 1500000000000}'),
('META', 'Meta Platforms Inc.', 'stock', 'stock', 'META', 'yahoo', 'META', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 1200000000000}'),
('TSLA', 'Tesla Inc.', 'stock', 'stock', 'TSLA', 'yahoo', 'TSLA', 'USD', 'NASDAQ', 'Consumer Cyclical', '{"market_cap": 800000000000}'),
('BRK-B', 'Berkshire Hathaway Inc.', 'stock', 'stock', 'BRK-B', 'yahoo', 'BRK-B', 'USD', 'NYSE', 'Financial Services', '{"market_cap": 900000000000}'),
('JPM', 'JPMorgan Chase & Co.', 'stock', 'stock', 'JPM', 'yahoo', 'JPM', 'USD', 'NYSE', 'Financial Services', '{"market_cap": 600000000000}'),
('V', 'Visa Inc.', 'stock', 'stock', 'V', 'yahoo', 'V', 'USD', 'NYSE', 'Financial Services', '{"market_cap": 550000000000}'),
('WMT', 'Walmart Inc.', 'stock', 'stock', 'WMT', 'yahoo', 'WMT', 'USD', 'NYSE', 'Consumer Defensive', '{"market_cap": 500000000000}'),
('MA', 'Mastercard Inc.', 'stock', 'stock', 'MA', 'yahoo', 'MA', 'USD', 'NYSE', 'Financial Services', '{"market_cap": 450000000000}'),
('PG', 'Procter & Gamble Co.', 'stock', 'stock', 'PG', 'yahoo', 'PG', 'USD', 'NYSE', 'Consumer Defensive', '{"market_cap": 400000000000}'),
('DIS', 'Walt Disney Co.', 'stock', 'stock', 'DIS', 'yahoo', 'DIS', 'USD', 'NYSE', 'Communication Services', '{"market_cap": 200000000000}'),
('NFLX', 'Netflix Inc.', 'stock', 'stock', 'NFLX', 'yahoo', 'NFLX', 'USD', 'NASDAQ', 'Communication Services', '{"market_cap": 180000000000}'),
('COST', 'Costco Wholesale Corp.', 'stock', 'stock', 'COST', 'yahoo', 'COST', 'USD', 'NASDAQ', 'Consumer Defensive', '{"market_cap": 350000000000}'),
('PEP', 'PepsiCo Inc.', 'stock', 'stock', 'PEP', 'yahoo', 'PEP', 'USD', 'NASDAQ', 'Consumer Defensive', '{"market_cap": 240000000000}'),
('KO', 'Coca-Cola Co.', 'stock', 'stock', 'KO', 'yahoo', 'KO', 'USD', 'NYSE', 'Consumer Defensive', '{"market_cap": 280000000000}'),
('AMD', 'Advanced Micro Devices', 'stock', 'stock', 'AMD', 'yahoo', 'AMD', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 350000000000}'),
('INTC', 'Intel Corporation', 'stock', 'stock', 'INTC', 'yahoo', 'INTC', 'USD', 'NASDAQ', 'Technology', '{"market_cap": 200000000000}')
ON CONFLICT (symbol) DO NOTHING;

-- Insert 10 ETFs
INSERT INTO assets (symbol, name, type, category, code, provider, provider_id, currency, exchange, sector, metadata) VALUES
('SPY', 'SPDR S&P 500 ETF Trust', 'etf', 'etf', 'SPY', 'yahoo', 'SPY', 'USD', 'NYSE', 'Broad Market', '{"aum": 400000000000, "expense_ratio": 0.0945}'),
('QQQ', 'Invesco QQQ Trust', 'etf', 'etf', 'QQQ', 'yahoo', 'QQQ', 'USD', 'NASDAQ', 'Technology', '{"aum": 200000000000, "expense_ratio": 0.20}'),
('VOO', 'Vanguard S&P 500 ETF', 'etf', 'etf', 'VOO', 'yahoo', 'VOO', 'USD', 'NYSE', 'Broad Market', '{"aum": 350000000000, "expense_ratio": 0.03}'),
('VTI', 'Vanguard Total Stock Market ETF', 'etf', 'etf', 'VTI', 'yahoo', 'VTI', 'USD', 'NYSE', 'Broad Market', '{"aum": 300000000000, "expense_ratio": 0.03}'),
('IWM', 'iShares Russell 2000 ETF', 'etf', 'etf', 'IWM', 'yahoo', 'IWM', 'USD', 'NYSE', 'Small Cap', '{"aum": 60000000000, "expense_ratio": 0.19}'),
('EFA', 'iShares MSCI EAFE ETF', 'etf', 'etf', 'EFA', 'yahoo', 'EFA', 'USD', 'NYSE', 'International', '{"aum": 70000000000, "expense_ratio": 0.32}'),
('AGG', 'iShares Core U.S. Aggregate Bond ETF', 'etf', 'etf', 'AGG', 'yahoo', 'AGG', 'USD', 'NYSE', 'Bonds', '{"aum": 90000000000, "expense_ratio": 0.03}'),
('TLT', 'iShares 20+ Year Treasury Bond ETF', 'etf', 'etf', 'TLT', 'yahoo', 'TLT', 'USD', 'NASDAQ', 'Bonds', '{"aum": 40000000000, "expense_ratio": 0.15}'),
('GLD', 'SPDR Gold Shares', 'etf', 'etf', 'GLD', 'yahoo', 'GLD', 'USD', 'NYSE', 'Commodities', '{"aum": 60000000000, "expense_ratio": 0.40}'),
('ARKK', 'ARK Innovation ETF', 'etf', 'etf', 'ARKK', 'yahoo', 'ARKK', 'USD', 'NYSE', 'Innovation', '{"aum": 8000000000, "expense_ratio": 0.75}')
ON CONFLICT (symbol) DO NOTHING;

-- Insert 7 FX Pairs (USD Based)
INSERT INTO assets (symbol, name, type, category, code, provider, provider_id, currency, metadata) VALUES
('EURUSD', 'Euro / US Dollar', 'fx', 'fx', 'EURUSD', 'yahoo', 'EURUSD', 'USD', '{"base": "EUR", "quote": "USD"}'),
('GBPUSD', 'British Pound / US Dollar', 'fx', 'fx', 'GBPUSD', 'yahoo', 'GBPUSD', 'USD', '{"base": "GBP", "quote": "USD"}'),
('TRYUSD', 'Turkish Lira / US Dollar', 'fx', 'fx', 'TRYUSD', 'yahoo', 'TRYUSD', 'USD', '{"base": "TRY", "quote": "USD"}'),
('JPYUSD', 'Japanese Yen / US Dollar', 'fx', 'fx', 'JPYUSD', 'yahoo', 'JPYUSD', 'USD', '{"base": "JPY", "quote": "USD"}'),
('AUDUSD', 'Australian Dollar / US Dollar', 'fx', 'fx', 'AUDUSD', 'yahoo', 'AUDUSD', 'USD', '{"base": "AUD", "quote": "USD"}'),
('CHFUSD', 'Swiss Franc / US Dollar', 'fx', 'fx', 'CHFUSD', 'yahoo', 'CHFUSD', 'USD', '{"base": "CHF", "quote": "USD"}'),
('CADUSD', 'Canadian Dollar / US Dollar', 'fx', 'fx', 'CADUSD', 'yahoo', 'CADUSD', 'USD', '{"base": "CAD", "quote": "USD"}')
ON CONFLICT (symbol) DO NOTHING;

-- Insert 4 Metals
INSERT INTO assets (symbol, name, type, category, code, provider, provider_id, currency, metadata) VALUES
('XAU', 'Gold', 'metal', 'metal', 'XAUUSD', 'goldapi', 'XAU', 'USD', '{"unit": "troy_ounce"}'),
('XAG', 'Silver', 'metal', 'metal', 'XAGUSD', 'goldapi', 'XAG', 'USD', '{"unit": "troy_ounce"}'),
('XPT', 'Platinum', 'metal', 'metal', 'XPTUSD', 'goldapi', 'XPT', 'USD', '{"unit": "troy_ounce"}'),
('XPD', 'Palladium', 'metal', 'metal', 'XPDUSD', 'goldapi', 'XPD', 'USD', '{"unit": "troy_ounce"}')
ON CONFLICT (symbol) DO NOTHING;

-- Verify asset count
DO $$
DECLARE
    asset_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO asset_count FROM assets;
    RAISE NOTICE 'Total assets seeded: %', asset_count;
    
    IF asset_count < 64 THEN
        RAISE WARNING 'Expected 64 assets, but only % were inserted', asset_count;
    END IF;
END $$;
