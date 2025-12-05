-- Migration: Seed MVP assets (64 assets)
-- Description: Insert 20 crypto, 20 stocks, 10 ETFs, 10 FX pairs, 4 metals

-- Clear existing data (optional - uncomment if needed)
-- TRUNCATE TABLE assets CASCADE;

-- Crypto Assets (20)
INSERT INTO assets (symbol, name, type, provider_id, currency) VALUES
('BTCUSDT', 'Bitcoin', 'crypto', 'BTCUSDT', 'USD'),
('ETHUSDT', 'Ethereum', 'crypto', 'ETHUSDT', 'USD'),
('SOLUSDT', 'Solana', 'crypto', 'SOLUSDT', 'USD'),
('TONUSDT', 'Toncoin', 'crypto', 'TONUSDT', 'USD'),
('XRPUSDT', 'Ripple', 'crypto', 'XRPUSDT', 'USD'),
('ADAUSDT', 'Cardano', 'crypto', 'ADAUSDT', 'USD'),
('AVAXUSDT', 'Avalanche', 'crypto', 'AVAXUSDT', 'USD'),
('DOTUSDT', 'Polkadot', 'crypto', 'DOTUSDT', 'USD'),
('DOGEUSDT', 'Dogecoin', 'crypto', 'DOGEUSDT', 'USD'),
('MATICUSDT', 'Polygon', 'crypto', 'MATICUSDT', 'USD'),
('ATOMUSDT', 'Cosmos', 'crypto', 'ATOMUSDT', 'USD'),
('LINKUSDT', 'Chainlink', 'crypto', 'LINKUSDT', 'USD'),
('TRXUSDT', 'TRON', 'crypto', 'TRXUSDT', 'USD'),
('BNBUSDT', 'BNB', 'crypto', 'BNBUSDT', 'USD'),
('OPUSDT', 'Optimism', 'crypto', 'OPUSDT', 'USD'),
('ARBUSDT', 'Arbitrum', 'crypto', 'ARBUSDT', 'USD'),
('AAVEUSDT', 'Aave', 'crypto', 'AAVEUSDT', 'USD'),
('SUIUSDT', 'Sui', 'crypto', 'SUIUSDT', 'USD'),
('NEARUSDT', 'NEAR Protocol', 'crypto', 'NEARUSDT', 'USD'),
('INJUSDT', 'Injective', 'crypto', 'INJUSDT', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- US Stocks (20)
INSERT INTO assets (symbol, name, type, provider_id, currency) VALUES
('AAPL', 'Apple Inc.', 'stock', 'AAPL', 'USD'),
('MSFT', 'Microsoft Corporation', 'stock', 'MSFT', 'USD'),
('NVDA', 'NVIDIA Corporation', 'stock', 'NVDA', 'USD'),
('AMZN', 'Amazon.com Inc.', 'stock', 'AMZN', 'USD'),
('META', 'Meta Platforms Inc.', 'stock', 'META', 'USD'),
('TSLA', 'Tesla Inc.', 'stock', 'TSLA', 'USD'),
('JPM', 'JPMorgan Chase & Co.', 'stock', 'JPM', 'USD'),
('WMT', 'Walmart Inc.', 'stock', 'WMT', 'USD'),
('BRK-B', 'Berkshire Hathaway Inc.', 'stock', 'BRK-B', 'USD'),
('GOOG', 'Alphabet Inc.', 'stock', 'GOOG', 'USD'),
('NFLX', 'Netflix Inc.', 'stock', 'NFLX', 'USD'),
('COST', 'Costco Wholesale Corporation', 'stock', 'COST', 'USD'),
('V', 'Visa Inc.', 'stock', 'V', 'USD'),
('MA', 'Mastercard Incorporated', 'stock', 'MA', 'USD'),
('KO', 'The Coca-Cola Company', 'stock', 'KO', 'USD'),
('PEP', 'PepsiCo Inc.', 'stock', 'PEP', 'USD'),
('AMD', 'Advanced Micro Devices Inc.', 'stock', 'AMD', 'USD'),
('CRM', 'Salesforce Inc.', 'stock', 'CRM', 'USD'),
('ORCL', 'Oracle Corporation', 'stock', 'ORCL', 'USD'),
('BAC', 'Bank of America Corporation', 'stock', 'BAC', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- ETFs (10)
INSERT INTO assets (symbol, name, type, provider_id, currency) VALUES
('SPY', 'SPDR S&P 500 ETF Trust', 'etf', 'SPY', 'USD'),
('QQQ', 'Invesco QQQ Trust', 'etf', 'QQQ', 'USD'),
('VOO', 'Vanguard S&P 500 ETF', 'etf', 'VOO', 'USD'),
('TLT', 'iShares 20+ Year Treasury Bond ETF', 'etf', 'TLT', 'USD'),
('GLD', 'SPDR Gold Shares', 'etf', 'GLD', 'USD'),
('ARKK', 'ARK Innovation ETF', 'etf', 'ARKK', 'USD'),
('DIA', 'SPDR Dow Jones Industrial Average ETF', 'etf', 'DIA', 'USD'),
('XLK', 'Technology Select Sector SPDR Fund', 'etf', 'XLK', 'USD'),
('XLF', 'Financial Select Sector SPDR Fund', 'etf', 'XLF', 'USD'),
('IWM', 'iShares Russell 2000 ETF', 'etf', 'IWM', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- FX Pairs (7)
INSERT INTO assets (symbol, name, type, provider_id, currency) VALUES
('EURUSD', 'Euro / US Dollar', 'fx', 'EURUSD', 'USD'),
('GBPUSD', 'British Pound / US Dollar', 'fx', 'GBPUSD', 'USD'),
('TRYUSD', 'Turkish Lira / US Dollar', 'fx', 'TRYUSD', 'USD'),
('JPYUSD', 'Japanese Yen / US Dollar', 'fx', 'JPYUSD', 'USD'),
('AUDUSD', 'Australian Dollar / US Dollar', 'fx', 'AUDUSD', 'USD'),
('CHFUSD', 'Swiss Franc / US Dollar', 'fx', 'CHFUSD', 'USD'),
('CADUSD', 'Canadian Dollar / US Dollar', 'fx', 'CADUSD', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- Metals (4)
INSERT INTO assets (symbol, name, type, provider_id, currency) VALUES
('XAUUSD', 'Gold', 'metal', 'XAUUSD', 'USD'),
('XAGUSD', 'Silver', 'metal', 'XAGUSD', 'USD'),
('XPTUSD', 'Platinum', 'metal', 'XPTUSD', 'USD'),
('XPDUSD', 'Palladium', 'metal', 'XPDUSD', 'USD')
ON CONFLICT (symbol) DO NOTHING;

-- Verify insertion
SELECT type, COUNT(*) as count FROM assets GROUP BY type ORDER BY type;
