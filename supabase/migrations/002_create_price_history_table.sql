-- Migration: Create price_history table
-- Description: Historical OHLCV price data for all assets

CREATE TABLE IF NOT EXISTS price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  open FLOAT,
  high FLOAT,
  low FLOAT,
  close FLOAT NOT NULL,
  volume FLOAT,
  provider TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_asset_date UNIQUE(asset_id, date)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_price_history_asset_id ON price_history(asset_id);
CREATE INDEX IF NOT EXISTS idx_price_history_date ON price_history(date);
CREATE INDEX IF NOT EXISTS idx_price_history_asset_date ON price_history(asset_id, date DESC);

-- Add comments
COMMENT ON TABLE price_history IS 'Historical OHLCV price data';
COMMENT ON COLUMN price_history.asset_id IS 'Reference to assets table';
COMMENT ON COLUMN price_history.date IS 'Trading date';
COMMENT ON COLUMN price_history.close IS 'Closing price (required)';
COMMENT ON COLUMN price_history.provider IS 'Data source (Binance, Yahoo, etc.)';
