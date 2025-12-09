-- Migration: Standardize Forex Pairs to XXXUSD Format
-- Description: Convert all forex pairs to USD quote format (1 XXX = ? USD)
-- Date: 2025-12-08
-- Schema: 
--   assets: symbol, display_name, asset_class
--   prices_history: asset_id (references assets.id), open, high, low, close

-- ============================================
-- PHASE 1: Rename Asset Symbols (USDXXX → XXXUSD)
-- Note: These may have already been executed
-- ============================================

-- Major pairs that need inversion
UPDATE assets SET 
    symbol = 'JPYUSD', 
    display_name = 'Japanese Yen / US Dollar'
WHERE symbol = 'USDJPY' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'CHFUSD', 
    display_name = 'Swiss Franc / US Dollar'
WHERE symbol = 'USDCHF' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'CADUSD', 
    display_name = 'Canadian Dollar / US Dollar'
WHERE symbol = 'USDCAD' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'TRYUSD', 
    display_name = 'Turkish Lira / US Dollar'
WHERE symbol = 'USDTRY' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'CNYUSD', 
    display_name = 'Chinese Yuan / US Dollar'
WHERE symbol = 'USDCNY' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'INRUSD', 
    display_name = 'Indian Rupee / US Dollar'
WHERE symbol = 'USDINR' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'BRLUSD', 
    display_name = 'Brazilian Real / US Dollar'
WHERE symbol = 'USDBRL' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'MXNUSD', 
    display_name = 'Mexican Peso / US Dollar'
WHERE symbol = 'USDMXN' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'ZARUSD', 
    display_name = 'South African Rand / US Dollar'
WHERE symbol = 'USDZAR' AND asset_class = 'forex';

UPDATE assets SET 
    symbol = 'RUBUSD', 
    display_name = 'Russian Ruble / US Dollar'
WHERE symbol = 'USDRUB' AND asset_class = 'forex';

-- ============================================
-- PHASE 2: Update Historical Prices (prices_history)
-- Uses asset_id JOIN since prices_history doesn't have symbol column
-- ============================================

-- Invert prices for all affected forex pairs
-- Formula: new_price = 1 / old_price
-- Note: high becomes 1/low and low becomes 1/high when inverting

UPDATE prices_history ph
SET 
    close = CASE WHEN ph.close > 0 THEN 1.0 / ph.close ELSE 0 END,
    open = CASE WHEN ph.open > 0 THEN 1.0 / ph.open ELSE 0 END,
    high = CASE WHEN ph.low > 0 THEN 1.0 / ph.low ELSE 0 END,
    low = CASE WHEN ph.high > 0 THEN 1.0 / ph.high ELSE 0 END
FROM assets a
WHERE ph.asset_id = a.id 
  AND a.asset_class = 'forex'
  AND a.symbol IN ('JPYUSD', 'CHFUSD', 'CADUSD', 'TRYUSD', 'CNYUSD', 'INRUSD', 'BRLUSD', 'MXNUSD', 'ZARUSD', 'RUBUSD');

-- ============================================
-- PHASE 3: Update Latest Prices (SKIPPED)
-- Note: latest_prices table does not exist in this database
-- ============================================

-- ============================================
-- VERIFICATION QUERIES (Run after migration)
-- ============================================

-- Check asset symbols
-- SELECT symbol, display_name FROM assets WHERE asset_class = 'forex' ORDER BY symbol;

-- Check sample prices (JPYUSD should be ~0.0065)
-- SELECT a.symbol, ph.date, ph.close 
-- FROM prices_history ph
-- JOIN assets a ON ph.asset_id = a.id
-- WHERE a.symbol = 'JPYUSD' AND ph.date >= '2024-12-01' 
-- ORDER BY ph.date DESC LIMIT 5;

-- Check TRYUSD (should be ~0.028)
-- SELECT a.symbol, ph.date, ph.close 
-- FROM prices_history ph
-- JOIN assets a ON ph.asset_id = a.id
-- WHERE a.symbol = 'TRYUSD' AND ph.date >= '2024-12-01' 
-- ORDER BY ph.date DESC LIMIT 5;

