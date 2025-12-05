-- Migration: Create portfolio tables
-- Description: Portfolio holdings and transaction history

-- Portfolio Holdings Table
CREATE TABLE IF NOT EXISTS portfolio_holdings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL,
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  quantity FLOAT NOT NULL CHECK (quantity >= 0),
  avg_price FLOAT NOT NULL CHECK (avg_price >= 0),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_portfolio_asset UNIQUE(portfolio_id, asset_id)
);

-- Portfolio Transactions Table
CREATE TABLE IF NOT EXISTS portfolio_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL,
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('buy', 'sell')),
  quantity FLOAT NOT NULL CHECK (quantity > 0),
  price FLOAT NOT NULL CHECK (price >= 0),
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for holdings
CREATE INDEX IF NOT EXISTS idx_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_holdings_asset_id ON portfolio_holdings(asset_id);

-- Create indexes for transactions
CREATE INDEX IF NOT EXISTS idx_transactions_portfolio_id ON portfolio_transactions(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transactions_asset_id ON portfolio_transactions(asset_id);
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON portfolio_transactions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON portfolio_transactions(type);

-- Create updated_at trigger for holdings
CREATE TRIGGER update_portfolio_holdings_updated_at BEFORE UPDATE ON portfolio_holdings
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE portfolio_holdings IS 'Current portfolio positions';
COMMENT ON TABLE portfolio_transactions IS 'Transaction history for portfolios';
COMMENT ON COLUMN portfolio_holdings.avg_price IS 'Average purchase price';
COMMENT ON COLUMN portfolio_transactions.type IS 'Transaction type: buy or sell';
