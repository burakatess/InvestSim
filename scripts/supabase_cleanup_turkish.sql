-- ========================================
-- SUPABASE BACKUP: Turkish Assets
-- Run this FIRST before any deletions
-- ========================================

-- 1. Create backup table
CREATE TABLE IF NOT EXISTS assets_backup_turkish (
    id UUID PRIMARY KEY,
    code TEXT,
    name TEXT,
    symbol TEXT,
    category TEXT,
    provider TEXT,
    is_websocket BOOLEAN,
    websocket_provider TEXT,
    created_at TIMESTAMP,
    backed_up_at TIMESTAMP DEFAULT NOW()
);

-- 2. Backup BIST stocks
INSERT INTO assets_backup_turkish
SELECT 
    id, code, name, symbol, category, provider, 
    is_websocket, websocket_provider, created_at, NOW()
FROM assets
WHERE category = 'bist_stock' 
   OR (provider = 'yahoo' AND symbol LIKE '%.IS');

-- 3. Backup TEFAS funds
INSERT INTO assets_backup_turkish
SELECT 
    id, code, name, symbol, category, provider, 
    is_websocket, websocket_provider, created_at, NOW()
FROM assets
WHERE category = 'tefas_fund' 
   OR provider = 'tefas';

-- 4. Verify backup
SELECT 
    category,
    COUNT(*) as backed_up_count
FROM assets_backup_turkish
GROUP BY category
ORDER BY category;

-- Expected output: Should show counts for bist_stock and tefas_fund

-- ========================================
-- CLEANUP: Delete Turkish Assets
-- Run this AFTER backup is verified
-- ========================================

-- 5. Delete BIST stocks
DELETE FROM assets 
WHERE category = 'bist_stock' 
   OR (provider = 'yahoo' AND symbol LIKE '%.IS');

-- 6. Delete TEFAS funds
DELETE FROM assets 
WHERE category = 'tefas_fund' 
   OR provider = 'tefas';

-- 7. Verify deletion
SELECT 
    category,
    COUNT(*) as remaining_count
FROM assets
WHERE category NOT IN ('bist_stock', 'tefas_fund')
GROUP BY category
ORDER BY category;

-- Expected: No bist_stock or tefas_fund should appear

-- 8. Final count
SELECT COUNT(*) as total_remaining FROM assets;
