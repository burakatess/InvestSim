-- Add Oil, Natural Gas and update metal assets for AlphaVantage provider

-- First, remove duplicate metal entries (keep only one per code)
WITH duplicates AS (
    SELECT id, code, 
           ROW_NUMBER() OVER (PARTITION BY code ORDER BY created_at) as rn
    FROM assets 
    WHERE code IN ('XAUUSD', 'XAGUSD', 'XPTUSD', 'XPDUSD')
)
DELETE FROM assets WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- Update metal assets to use alphavantage provider
UPDATE assets 
SET provider = 'alphavantage',
    type = 'commodity'
WHERE code IN ('XAUUSD', 'XAGUSD', 'XPTUSD', 'XPDUSD');

-- Add new commodity assets (Oil, Natural Gas)
INSERT INTO assets (code, name, type, provider, is_active, created_at) VALUES
    -- Energy
    ('WTI', 'WTI Crude Oil', 'commodity', 'alphavantage', true, NOW()),
    ('BRENT', 'Brent Crude Oil', 'commodity', 'alphavantage', true, NOW()),
    ('NATGAS', 'Natural Gas', 'commodity', 'alphavantage', true, NOW()),
    -- Agricultural (bonus)
    ('WHEAT', 'Wheat', 'commodity', 'alphavantage', true, NOW()),
    ('CORN', 'Corn', 'commodity', 'alphavantage', true, NOW()),
    ('COFFEE', 'Coffee', 'commodity', 'alphavantage', true, NOW())
ON CONFLICT (code) DO UPDATE SET
    provider = 'alphavantage',
    type = 'commodity',
    is_active = true;
