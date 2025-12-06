-- ============================================
-- INVESTSIMULATOR SEED DATA
-- 74 Assets: 20 Crypto, 20 Stocks, 10 ETFs, 10 FX, 4 Metals
-- ============================================

-- ============================================
-- A) CRYPTO (20) - Binance
-- ============================================
INSERT INTO assets (symbol, display_name, asset_class, provider, provider_symbol, currency) VALUES
('BTCUSDT', 'Bitcoin', 'crypto', 'binance', 'BTCUSDT', 'USD'),
('ETHUSDT', 'Ethereum', 'crypto', 'binance', 'ETHUSDT', 'USD'),
('SOLUSDT', 'Solana', 'crypto', 'binance', 'SOLUSDT', 'USD'),
('TONUSDT', 'Toncoin', 'crypto', 'binance', 'TONUSDT', 'USD'),
('XRPUSDT', 'Ripple', 'crypto', 'binance', 'XRPUSDT', 'USD'),
('ADAUSDT', 'Cardano', 'crypto', 'binance', 'ADAUSDT', 'USD'),
('AVAXUSDT', 'Avalanche', 'crypto', 'binance', 'AVAXUSDT', 'USD'),
('DOTUSDT', 'Polkadot', 'crypto', 'binance', 'DOTUSDT', 'USD'),
('DOGEUSDT', 'Dogecoin', 'crypto', 'binance', 'DOGEUSDT', 'USD'),
('MATICUSDT', 'Polygon', 'crypto', 'binance', 'MATICUSDT', 'USD'),
('ATOMUSDT', 'Cosmos', 'crypto', 'binance', 'ATOMUSDT', 'USD'),
('LINKUSDT', 'Chainlink', 'crypto', 'binance', 'LINKUSDT', 'USD'),
('TRXUSDT', 'TRON', 'crypto', 'binance', 'TRXUSDT', 'USD'),
('BNBUSDT', 'BNB', 'crypto', 'binance', 'BNBUSDT', 'USD'),
('OPUSDT', 'Optimism', 'crypto', 'binance', 'OPUSDT', 'USD'),
('ARBUSDT', 'Arbitrum', 'crypto', 'binance', 'ARBUSDT', 'USD'),
('AAVEUSDT', 'Aave', 'crypto', 'binance', 'AAVEUSDT', 'USD'),
('SUIUSDT', 'Sui', 'crypto', 'binance', 'SUIUSDT', 'USD'),
('NEARUSDT', 'NEAR Protocol', 'crypto', 'binance', 'NEARUSDT', 'USD'),
('INJUSDT', 'Injective', 'crypto', 'binance', 'INJUSDT', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- ============================================
-- B) US STOCKS (20) - Yahoo Finance
-- ============================================
INSERT INTO assets (symbol, display_name, asset_class, provider, provider_symbol, currency) VALUES
('AAPL', 'Apple Inc.', 'stock', 'yahoo', 'AAPL', 'USD'),
('MSFT', 'Microsoft Corporation', 'stock', 'yahoo', 'MSFT', 'USD'),
('NVDA', 'NVIDIA Corporation', 'stock', 'yahoo', 'NVDA', 'USD'),
('AMZN', 'Amazon.com Inc.', 'stock', 'yahoo', 'AMZN', 'USD'),
('META', 'Meta Platforms Inc.', 'stock', 'yahoo', 'META', 'USD'),
('TSLA', 'Tesla Inc.', 'stock', 'yahoo', 'TSLA', 'USD'),
('JPM', 'JPMorgan Chase & Co.', 'stock', 'yahoo', 'JPM', 'USD'),
('WMT', 'Walmart Inc.', 'stock', 'yahoo', 'WMT', 'USD'),
('BRK-B', 'Berkshire Hathaway B', 'stock', 'yahoo', 'BRK-B', 'USD'),
('GOOG', 'Alphabet Inc.', 'stock', 'yahoo', 'GOOG', 'USD'),
('NFLX', 'Netflix Inc.', 'stock', 'yahoo', 'NFLX', 'USD'),
('COST', 'Costco Wholesale', 'stock', 'yahoo', 'COST', 'USD'),
('V', 'Visa Inc.', 'stock', 'yahoo', 'V', 'USD'),
('MA', 'Mastercard Inc.', 'stock', 'yahoo', 'MA', 'USD'),
('KO', 'Coca-Cola Company', 'stock', 'yahoo', 'KO', 'USD'),
('PEP', 'PepsiCo Inc.', 'stock', 'yahoo', 'PEP', 'USD'),
('AMD', 'Advanced Micro Devices', 'stock', 'yahoo', 'AMD', 'USD'),
('CRM', 'Salesforce Inc.', 'stock', 'yahoo', 'CRM', 'USD'),
('ORCL', 'Oracle Corporation', 'stock', 'yahoo', 'ORCL', 'USD'),
('BAC', 'Bank of America', 'stock', 'yahoo', 'BAC', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- ============================================
-- C) ETFs (10) - Yahoo Finance
-- ============================================
INSERT INTO assets (symbol, display_name, asset_class, provider, provider_symbol, currency) VALUES
('SPY', 'SPDR S&P 500 ETF', 'etf', 'yahoo', 'SPY', 'USD'),
('QQQ', 'Invesco QQQ Trust', 'etf', 'yahoo', 'QQQ', 'USD'),
('VOO', 'Vanguard S&P 500 ETF', 'etf', 'yahoo', 'VOO', 'USD'),
('TLT', 'iShares 20+ Year Treasury', 'etf', 'yahoo', 'TLT', 'USD'),
('GLD', 'SPDR Gold Shares', 'etf', 'yahoo', 'GLD', 'USD'),
('ARKK', 'ARK Innovation ETF', 'etf', 'yahoo', 'ARKK', 'USD'),
('DIA', 'SPDR Dow Jones Industrial', 'etf', 'yahoo', 'DIA', 'USD'),
('XLK', 'Technology Select Sector', 'etf', 'yahoo', 'XLK', 'USD'),
('XLF', 'Financial Select Sector', 'etf', 'yahoo', 'XLF', 'USD'),
('IWM', 'iShares Russell 2000 ETF', 'etf', 'yahoo', 'IWM', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- ============================================
-- D) FX PAIRS (10) - exchangerate.host
-- ============================================
INSERT INTO assets (symbol, display_name, asset_class, provider, provider_symbol, currency) VALUES
('USDTRY', 'USD/TRY', 'fx', 'fx', 'TRY', 'TRY'),
('EURTRY', 'EUR/TRY', 'fx', 'fx', 'EURTRY', 'TRY'),
('GBPTRY', 'GBP/TRY', 'fx', 'fx', 'GBPTRY', 'TRY'),
('JPYTRY', 'JPY/TRY', 'fx', 'fx', 'JPYTRY', 'TRY'),
('CHFTRY', 'CHF/TRY', 'fx', 'fx', 'CHFTRY', 'TRY'),
('EURUSD', 'EUR/USD', 'fx', 'fx', 'EUR', 'USD'),
('USDJPY', 'USD/JPY', 'fx', 'fx', 'JPY', 'JPY'),
('GBPUSD', 'GBP/USD', 'fx', 'fx', 'GBP', 'USD'),
('AUDUSD', 'AUD/USD', 'fx', 'fx', 'AUD', 'USD'),
('USDCAD', 'USD/CAD', 'fx', 'fx', 'CAD', 'CAD')
ON CONFLICT (symbol) DO NOTHING;

-- ============================================
-- E) METALS (4) - metals.live
-- ============================================
INSERT INTO assets (symbol, display_name, asset_class, provider, provider_symbol, currency) VALUES
('XAUUSD', 'Gold', 'metal', 'metals', 'gold', 'USD'),
('XAGUSD', 'Silver', 'metal', 'metals', 'silver', 'USD'),
('XPTUSD', 'Platinum', 'metal', 'metals', 'platinum', 'USD'),
('XPDUSD', 'Palladium', 'metal', 'metals', 'palladium', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- ============================================
-- VERIFY: Count assets by class
-- ============================================
-- SELECT asset_class, COUNT(*) FROM assets GROUP BY asset_class ORDER BY asset_class;
-- Expected: crypto=20, etf=10, fx=10, metal=4, stock=20 (Total: 64)
-- Note: There are 64 assets listed above (typo in original: said 74)
