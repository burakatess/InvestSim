-- ============================================
-- INVESTSIMULATOR BACKEND SCHEMA v2.0
-- Complete database schema for Supabase
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. ASSETS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    asset_class TEXT NOT NULL CHECK (asset_class IN ('crypto', 'stock', 'etf', 'fx', 'metal')),
    provider TEXT NOT NULL CHECK (provider IN ('binance', 'yahoo', 'fx', 'metals')),
    provider_symbol TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_assets_class ON assets(asset_class);
CREATE INDEX idx_assets_provider ON assets(provider);
CREATE INDEX idx_assets_provider_symbol ON assets(provider_symbol);
CREATE INDEX idx_assets_active ON assets(is_active) WHERE is_active = true;

-- ============================================
-- 2. PRICES_LATEST TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS prices_latest (
    asset_id UUID PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
    price NUMERIC NOT NULL,
    percent_change_24h NUMERIC,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source TEXT NOT NULL
);

-- ============================================
-- 3. PRICES_HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS prices_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    open NUMERIC,
    high NUMERIC,
    low NUMERIC,
    close NUMERIC NOT NULL,
    volume NUMERIC,
    provider TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (asset_id, date)
);

CREATE INDEX idx_prices_history_asset_date ON prices_history(asset_id, date DESC);

-- ============================================
-- 4. FORECAST_PREDICTIONS TABLE (Future ML)
-- ============================================
CREATE TABLE IF NOT EXISTS forecast_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    horizon TEXT NOT NULL CHECK (horizon IN ('3d', '7d', '30d', '3m', '1y', '3y')),
    predicted_date DATE NOT NULL,
    predicted_price NUMERIC NOT NULL,
    model_name TEXT NOT NULL,
    confidence NUMERIC CHECK (confidence >= 0 AND confidence <= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_forecast_asset_horizon ON forecast_predictions(asset_id, horizon);

-- ============================================
-- 5. PORTFOLIOS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS portfolios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    base_currency TEXT NOT NULL DEFAULT 'TRY',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_portfolios_user ON portfolios(user_id);

-- ============================================
-- 6. PORTFOLIO_POSITIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS portfolio_positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    quantity NUMERIC NOT NULL,
    avg_price NUMERIC NOT NULL,
    UNIQUE (portfolio_id, asset_id)
);

CREATE INDEX idx_positions_portfolio ON portfolio_positions(portfolio_id);

-- ============================================
-- 7. PORTFOLIO_TRANSACTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS portfolio_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    side TEXT NOT NULL CHECK (side IN ('buy', 'sell')),
    quantity NUMERIC NOT NULL,
    price NUMERIC NOT NULL,
    fee NUMERIC DEFAULT 0,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_portfolio_tx_portfolio_time ON portfolio_transactions(portfolio_id, timestamp DESC);

-- ============================================
-- TRIGGERS: Auto-update updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_assets_updated_at
    BEFORE UPDATE ON assets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_portfolios_updated_at
    BEFORE UPDATE ON portfolios
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE prices_latest ENABLE ROW LEVEL SECURITY;
ALTER TABLE prices_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE forecast_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_transactions ENABLE ROW LEVEL SECURITY;

-- Public read access for assets and prices
CREATE POLICY "Assets are viewable by everyone" ON assets FOR SELECT USING (true);
CREATE POLICY "Latest prices are viewable by everyone" ON prices_latest FOR SELECT USING (true);
CREATE POLICY "Price history is viewable by everyone" ON prices_history FOR SELECT USING (true);
CREATE POLICY "Forecasts are viewable by everyone" ON forecast_predictions FOR SELECT USING (true);

-- Service role can do everything
CREATE POLICY "Service role full access assets" ON assets FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access prices_latest" ON prices_latest FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access prices_history" ON prices_history FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access forecasts" ON forecast_predictions FOR ALL USING (auth.role() = 'service_role');

-- Portfolios: users can only access their own
CREATE POLICY "Users can view own portfolios" ON portfolios FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own portfolios" ON portfolios FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own portfolios" ON portfolios FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own portfolios" ON portfolios FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own positions" ON portfolio_positions FOR SELECT 
    USING (portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage own positions" ON portfolio_positions FOR ALL 
    USING (portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid()));

CREATE POLICY "Users can view own transactions" ON portfolio_transactions FOR SELECT 
    USING (portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage own transactions" ON portfolio_transactions FOR ALL 
    USING (portfolio_id IN (SELECT id FROM portfolios WHERE user_id = auth.uid()));
