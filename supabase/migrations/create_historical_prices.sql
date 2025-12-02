-- Historical Prices Table Schema
-- For DCA simulation with 2-3 years of daily closing prices

CREATE TABLE IF NOT EXISTS historical_prices (
  id BIGSERIAL PRIMARY KEY,
  asset_code TEXT NOT NULL REFERENCES assets(code) ON DELETE CASCADE,
  date DATE NOT NULL,
  
  -- OHLC data (Open, High, Low, Close)
  open DECIMAL(20, 8),
  high DECIMAL(20, 8),
  low DECIMAL(20, 8),
  close DECIMAL(20, 8) NOT NULL,  -- Most important for DCA simulations
  
  -- Volume
  volume DECIMAL(20, 2),
  
  -- Metadata
  category TEXT NOT NULL,
  provider TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint: One record per asset per day
  CONSTRAINT unique_asset_date UNIQUE(asset_code, date)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_historical_prices_asset_date 
  ON historical_prices(asset_code, date DESC);

CREATE INDEX IF NOT EXISTS idx_historical_prices_date 
  ON historical_prices(date DESC);

CREATE INDEX IF NOT EXISTS idx_historical_prices_category 
  ON historical_prices(category);

CREATE INDEX IF NOT EXISTS idx_historical_prices_asset_category 
  ON historical_prices(asset_code, category);

-- RLS (Row Level Security) - Enable if needed
ALTER TABLE historical_prices ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access
CREATE POLICY "Allow public read access" 
  ON historical_prices 
  FOR SELECT 
  USING (true);

-- Policy: Allow service role full access
CREATE POLICY "Allow service role full access" 
  ON historical_prices 
  FOR ALL 
  USING (auth.role() = 'service_role');

-- Helper function: Get date range for an asset
CREATE OR REPLACE FUNCTION get_historical_date_range(p_asset_code TEXT)
RETURNS TABLE(min_date DATE, max_date DATE, total_days BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    MIN(date) as min_date,
    MAX(date) as max_date,
    COUNT(*) as total_days
  FROM historical_prices
  WHERE asset_code = p_asset_code;
END;
$$ LANGUAGE plpgsql;

-- Helper function: Get missing dates for an asset
CREATE OR REPLACE FUNCTION get_missing_dates(
  p_asset_code TEXT,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE(missing_date DATE) AS $$
BEGIN
  RETURN QUERY
  SELECT d::DATE
  FROM generate_series(p_start_date, p_end_date, '1 day'::interval) d
  WHERE d::DATE NOT IN (
    SELECT date 
    FROM historical_prices 
    WHERE asset_code = p_asset_code
      AND date BETWEEN p_start_date AND p_end_date
  )
  ORDER BY d;
END;
$$ LANGUAGE plpgsql;

-- Sample queries for testing

-- Get historical prices for an asset
-- SELECT date, close 
-- FROM historical_prices 
-- WHERE asset_code = 'BTC-bitcoin' 
--   AND date >= '2023-01-01'
-- ORDER BY date DESC;

-- Get summary by category
-- SELECT 
--   category,
--   COUNT(DISTINCT asset_code) as assets,
--   MIN(date) as earliest_date,
--   MAX(date) as latest_date,
--   COUNT(*) as total_records
-- FROM historical_prices
-- GROUP BY category;

-- Check missing dates for an asset
-- SELECT * FROM get_missing_dates('BTC-bitcoin', '2023-01-01', '2024-01-01');
