-- Migration: Create indicators table
-- Description: Technical indicators (RSI, MACD, Moving Averages)

CREATE TABLE IF NOT EXISTS indicators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  rsi FLOAT,
  macd FLOAT,
  signal FLOAT,
  ma50 FLOAT,
  ma200 FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_indicator_asset_date UNIQUE(asset_id, date)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_indicators_asset_id ON indicators(asset_id);
CREATE INDEX IF NOT EXISTS idx_indicators_date ON indicators(date);
CREATE INDEX IF NOT EXISTS idx_indicators_asset_date ON indicators(asset_id, date DESC);

-- Add comments
COMMENT ON TABLE indicators IS 'Technical indicators for assets';
COMMENT ON COLUMN indicators.rsi IS 'Relative Strength Index (0-100)';
COMMENT ON COLUMN indicators.macd IS 'MACD line value';
COMMENT ON COLUMN indicators.signal IS 'MACD signal line';
COMMENT ON COLUMN indicators.ma50 IS '50-day moving average';
COMMENT ON COLUMN indicators.ma200 IS '200-day moving average';
