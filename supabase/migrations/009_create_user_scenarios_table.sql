-- Migration: Create user_scenarios table for DCA scenario persistence
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS user_scenarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  frequency_per_month INTEGER NOT NULL DEFAULT 1,
  monthly_amount DECIMAL(18,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  annual_increase_percent DECIMAL(5,2) DEFAULT 0,
  -- Allocations: [{ "asset_code": "BTCUSDT", "percent": 50 }, ...]
  allocations JSONB NOT NULL DEFAULT '[]',
  -- Results (calculated after simulation)
  total_invested DECIMAL(18,2),
  final_value DECIMAL(18,2),
  roi_percent DECIMAL(10,4),
  -- Transaction history with purchase prices
  -- Format: [{ "date": "2024-12-10", "asset_code": "BTCUSDT", 
  --            "amount_usd": 100, "quantity": 0.0314, "unit_price": 31847.50 }]
  transactions_json JSONB,
  -- Sparkline data for chart
  sparkline_data JSONB DEFAULT '[]',
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_scenarios_user_id ON user_scenarios(user_id);
CREATE INDEX IF NOT EXISTS idx_user_scenarios_created ON user_scenarios(created_at DESC);

-- Row Level Security (users can only access their own scenarios)
ALTER TABLE user_scenarios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own scenarios" ON user_scenarios
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own scenarios" ON user_scenarios
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own scenarios" ON user_scenarios
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own scenarios" ON user_scenarios
  FOR DELETE USING (auth.uid() = user_id);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_scenarios_updated_at
    BEFORE UPDATE ON user_scenarios
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
