-- Migration: Fix FX Assets to USD pairs
-- Description: Replace existing FX assets with USD-based pairs as requested by user

-- 1. Delete existing FX assets
DELETE FROM assets WHERE type = 'fx';

-- 2. Insert new FX assets (USD based)
INSERT INTO assets (symbol, name, type, provider_id, currency) VALUES
('EURUSD', 'Euro / US Dollar', 'fx', 'EURUSD', 'USD'),
('GBPUSD', 'British Pound / US Dollar', 'fx', 'GBPUSD', 'USD'),
('TRYUSD', 'Turkish Lira / US Dollar', 'fx', 'TRYUSD', 'USD'),
('JPYUSD', 'Japanese Yen / US Dollar', 'fx', 'JPYUSD', 'USD'),
('AUDUSD', 'Australian Dollar / US Dollar', 'fx', 'AUDUSD', 'USD'),
('CHFUSD', 'Swiss Franc / US Dollar', 'fx', 'CHFUSD', 'USD'),
('CADUSD', 'Canadian Dollar / US Dollar', 'fx', 'CADUSD', 'USD');
