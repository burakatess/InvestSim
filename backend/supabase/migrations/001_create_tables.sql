-- ============================================================================
-- BACKEND MIGRATION - Compatible with Existing Schema
-- Updates existing assets table instead of recreating
-- ============================================================================

-- Add missing columns to existing assets table
ALTER TABLE assets ADD COLUMN IF NOT EXISTS provider TEXT DEFAULT 'yahoo';
ALTER TABLE assets ADD COLUMN IF NOT EXISTS provider_id TEXT;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS exchange TEXT;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS sector TEXT;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS market_cap BIGINT;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Set provider_id same as symbol if not set
UPDATE assets SET provider_id = symbol WHERE provider_id IS NULL;

-- Set provider based on type if not set
UPDATE assets SET provider = 
  CASE 
    WHEN type = 'crypto' THEN 'binance'
    WHEN type = 'stock' OR type = 'etf' THEN 'yahoo'
    WHEN type = 'fx' THEN 'tiingo'
    WHEN type = 'metal' THEN 'goldapi'
    ELSE 'yahoo'
  END
WHERE provider IS NULL OR provider = 'yahoo';


-- Add indexes for new columns
CREATE INDEX IF NOT EXISTS idx_assets_provider ON assets(provider);
CREATE INDEX IF NOT EXISTS idx_assets_exchange ON assets(exchange);

-- Create latest_prices table if not exists
CREATE TABLE IF NOT EXISTS latest_prices (
    asset_id UUID PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
    price DOUBLE PRECISION NOT NULL,
    open_24h DOUBLE PRECISION,
    high_24h DOUBLE PRECISION,
    low_24h DOUBLE PRECISION,
    volume_24h DOUBLE PRECISION,
    percent_change_1h DOUBLE PRECISION,
    percent_change_24h DOUBLE PRECISION,
    percent_change_7d DOUBLE PRECISION,
    market_cap BIGINT,
    provider TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_latest_prices_updated ON latest_prices(updated_at DESC);

-- Create price_history_daily table with partitioning
CREATE TABLE IF NOT EXISTS price_history_daily (
    id UUID DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    open DOUBLE PRECISION NOT NULL,
    high DOUBLE PRECISION NOT NULL,
    low DOUBLE PRECISION NOT NULL,
    close DOUBLE PRECISION NOT NULL,
    volume DOUBLE PRECISION,
    adj_close DOUBLE PRECISION,
    provider TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, date),
    CONSTRAINT unique_asset_date_daily UNIQUE (asset_id, date)
) PARTITION BY RANGE (date);

-- Create partitions for current and next year
CREATE TABLE IF NOT EXISTS price_history_daily_2025 PARTITION OF price_history_daily
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS price_history_daily_2026 PARTITION OF price_history_daily
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_price_history_daily_asset ON price_history_daily(asset_id);
CREATE INDEX IF NOT EXISTS idx_price_history_daily_date ON price_history_daily(date DESC);

-- Create price_history_weekly table
CREATE TABLE IF NOT EXISTS price_history_weekly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    open DOUBLE PRECISION NOT NULL,
    high DOUBLE PRECISION NOT NULL,
    low DOUBLE PRECISION NOT NULL,
    close DOUBLE PRECISION NOT NULL,
    volume DOUBLE PRECISION,
    provider TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_asset_week UNIQUE (asset_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_price_history_weekly_asset ON price_history_weekly(asset_id);
CREATE INDEX IF NOT EXISTS idx_price_history_weekly_date ON price_history_weekly(week_start DESC);

-- Create price_history_monthly table
CREATE TABLE IF NOT EXISTS price_history_monthly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    month_start DATE NOT NULL,
    open DOUBLE PRECISION NOT NULL,
    high DOUBLE PRECISION NOT NULL,
    low DOUBLE PRECISION NOT NULL,
    close DOUBLE PRECISION NOT NULL,
    volume DOUBLE PRECISION,
    provider TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_asset_month UNIQUE (asset_id, month_start)
);

CREATE INDEX IF NOT EXISTS idx_price_history_monthly_asset ON price_history_monthly(asset_id);
CREATE INDEX IF NOT EXISTS idx_price_history_monthly_date ON price_history_monthly(month_start DESC);

-- Create helper functions for aggregation
CREATE OR REPLACE FUNCTION aggregate_daily_to_weekly(p_asset_id UUID, p_week_start DATE)
RETURNS VOID AS $$
BEGIN
    INSERT INTO price_history_weekly (asset_id, week_start, open, high, low, close, volume, provider)
    SELECT 
        asset_id,
        p_week_start,
        (SELECT open FROM price_history_daily WHERE asset_id = p_asset_id AND date >= p_week_start AND date < p_week_start + INTERVAL '7 days' ORDER BY date ASC LIMIT 1),
        MAX(high),
        MIN(low),
        (SELECT close FROM price_history_daily WHERE asset_id = p_asset_id AND date >= p_week_start AND date < p_week_start + INTERVAL '7 days' ORDER BY date DESC LIMIT 1),
        SUM(volume),
        MAX(provider)
    FROM price_history_daily
    WHERE asset_id = p_asset_id 
      AND date >= p_week_start 
      AND date < p_week_start + INTERVAL '7 days'
    GROUP BY asset_id
    ON CONFLICT (asset_id, week_start) DO UPDATE
    SET open = EXCLUDED.open,
        high = EXCLUDED.high,
        low = EXCLUDED.low,
        close = EXCLUDED.close,
        volume = EXCLUDED.volume;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION aggregate_weekly_to_monthly(p_asset_id UUID, p_month_start DATE)
RETURNS VOID AS $$
BEGIN
    INSERT INTO price_history_monthly (asset_id, month_start, open, high, low, close, volume, provider)
    SELECT 
        asset_id,
        p_month_start,
        (SELECT open FROM price_history_weekly WHERE asset_id = p_asset_id AND week_start >= p_month_start AND week_start < p_month_start + INTERVAL '1 month' ORDER BY week_start ASC LIMIT 1),
        MAX(high),
        MIN(low),
        (SELECT close FROM price_history_weekly WHERE asset_id = p_asset_id AND week_start >= p_month_start AND week_start < p_month_start + INTERVAL '1 month' ORDER BY week_start DESC LIMIT 1),
        SUM(volume),
        MAX(provider)
    FROM price_history_weekly
    WHERE asset_id = p_asset_id 
      AND week_start >= p_month_start 
      AND week_start < p_month_start + INTERVAL '1 month'
    GROUP BY asset_id
    ON CONFLICT (asset_id, month_start) DO UPDATE
    SET open = EXCLUDED.open,
        high = EXCLUDED.high,
        low = EXCLUDED.low,
        close = EXCLUDED.close,
        volume = EXCLUDED.volume;
END;
$$ LANGUAGE plpgsql;

-- Create system_metrics table
CREATE TABLE IF NOT EXISTS system_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL,
    metric_value DOUBLE PRECISION NOT NULL,
    metadata JSONB,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_metrics_name ON system_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_system_metrics_time ON system_metrics(recorded_at DESC);
