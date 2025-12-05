-- Migration: Add code and category columns to assets table
-- Description: Add 'code' and 'category' columns for backward compatibility

-- Add code column (alias for symbol)
ALTER TABLE assets ADD COLUMN IF NOT EXISTS code TEXT;

-- Add category column (alias for type)
ALTER TABLE assets ADD COLUMN IF NOT EXISTS category TEXT;

-- Update columns to match existing data
UPDATE assets SET code = symbol WHERE code IS NULL;
UPDATE assets SET category = type WHERE category IS NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_assets_code ON assets(code);
CREATE INDEX IF NOT EXISTS idx_assets_category ON assets(category);

-- Add comments
COMMENT ON COLUMN assets.code IS 'Asset code (same as symbol for backward compatibility)';
COMMENT ON COLUMN assets.category IS 'Asset category (same as type for backward compatibility)';
