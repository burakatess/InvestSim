-- Migration: Create assets table (with cleanup)
-- Description: Core table for all tradeable assets (crypto, stocks, ETFs, FX, metals)

-- Drop existing table if exists (CASCADE will drop dependent objects)
DROP TABLE IF EXISTS assets CASCADE;

-- Drop existing function if exists
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Create updated_at trigger function first
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create assets table
CREATE TABLE assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  currency TEXT DEFAULT 'USD',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_asset_type CHECK (type IN ('crypto', 'stock', 'etf', 'fx', 'metal'))
);

-- Create indexes for better query performance
CREATE INDEX idx_assets_type ON assets(type);
CREATE INDEX idx_assets_symbol ON assets(symbol);
CREATE INDEX idx_assets_is_active ON assets(is_active);

-- Create trigger
CREATE TRIGGER update_assets_updated_at 
BEFORE UPDATE ON assets
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE assets IS 'Core table storing all tradeable assets';
COMMENT ON COLUMN assets.symbol IS 'Unique asset symbol (e.g., BTCUSDT, AAPL)';
COMMENT ON COLUMN assets.type IS 'Asset category: crypto, stock, etf, fx, or metal';
COMMENT ON COLUMN assets.provider_id IS 'Provider-specific identifier (Binance symbol, Yahoo ticker, etc.)';
COMMENT ON COLUMN assets.currency IS 'Base currency for pricing (USD, TRY, etc.)';
