-- Fix commodity assets to use Yahoo Finance provider with correct symbols
-- Yahoo Finance uses futures symbols: GC=F (Gold), SI=F (Silver), etc.

-- First, ensure provider_id column exists
ALTER TABLE assets ADD COLUMN IF NOT EXISTS provider_id TEXT;

-- Remove duplicate metal entries (keep only first occurrence)
WITH duplicates AS (
    SELECT id, code, 
           ROW_NUMBER() OVER (PARTITION BY code ORDER BY created_at) as rn
    FROM assets 
    WHERE code IN ('XAUUSD', 'XAGUSD', 'XPTUSD', 'XPDUSD')
)
DELETE FROM assets WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- Update existing metal assets to use Yahoo provider with futures symbols
UPDATE assets SET 
    provider = 'yahoo',
    provider_id = CASE code
        WHEN 'XAUUSD' THEN 'GC=F'
        WHEN 'XAGUSD' THEN 'SI=F'
        WHEN 'XPTUSD' THEN 'PL=F'
        WHEN 'XPDUSD' THEN 'PA=F'
    END,
    type = 'commodity'
WHERE code IN ('XAUUSD', 'XAGUSD', 'XPTUSD', 'XPDUSD');

-- Add new commodity assets (Oil, Natural Gas, Agricultural)
INSERT INTO assets (code, name, type, provider, provider_id, is_active, created_at) VALUES
    -- Energy
    ('WTI', 'WTI Crude Oil', 'commodity', 'yahoo', 'CL=F', true, NOW()),
    ('BRENT', 'Brent Crude Oil', 'commodity', 'yahoo', 'BZ=F', true, NOW()),
    ('NATGAS', 'Natural Gas', 'commodity', 'yahoo', 'NG=F', true, NOW()),
    -- Agricultural
    ('WHEAT', 'Wheat Futures', 'commodity', 'yahoo', 'ZW=F', true, NOW()),
    ('CORN', 'Corn Futures', 'commodity', 'yahoo', 'ZC=F', true, NOW()),
    ('SOYBEAN', 'Soybean Futures', 'commodity', 'yahoo', 'ZS=F', true, NOW()),
    ('COFFEE', 'Coffee Futures', 'commodity', 'yahoo', 'KC=F', true, NOW()),
    ('SUGAR', 'Sugar Futures', 'commodity', 'yahoo', 'SB=F', true, NOW()),
    ('COTTON', 'Cotton Futures', 'commodity', 'yahoo', 'CT=F', true, NOW()),
    -- Base Metals
    ('COPPER', 'Copper Futures', 'commodity', 'yahoo', 'HG=F', true, NOW())
ON CONFLICT (code) DO UPDATE SET
    provider = EXCLUDED.provider,
    provider_id = EXCLUDED.provider_id,
    type = EXCLUDED.type,
    is_active = EXCLUDED.is_active;

-- Log the changes
DO $$
DECLARE
    commodity_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO commodity_count FROM assets WHERE type = 'commodity';
    RAISE NOTICE 'Total commodity assets: %', commodity_count;
END $$;
