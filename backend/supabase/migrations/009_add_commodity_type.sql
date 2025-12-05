-- Add 'commodity' to valid asset types
ALTER TABLE assets DROP CONSTRAINT IF EXISTS valid_asset_type;

ALTER TABLE assets ADD CONSTRAINT valid_asset_type 
CHECK (type IN ('stock', 'etf', 'crypto', 'fx', 'metal', 'commodity'));
