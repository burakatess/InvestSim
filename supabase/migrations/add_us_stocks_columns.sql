-- Add missing columns to assets table for US stocks/ETFs support

-- Add symbol column (for ticker symbols like AAPL, MSFT)
ALTER TABLE assets ADD COLUMN IF NOT EXISTS symbol TEXT;

-- Add metadata column (for storing sector, market cap, etc.)
ALTER TABLE assets ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Create index on symbol for faster lookups
CREATE INDEX IF NOT EXISTS idx_assets_symbol ON assets(symbol);

-- Update existing assets to have symbol = code where symbol is null
UPDATE assets SET symbol = code WHERE symbol IS NULL;
