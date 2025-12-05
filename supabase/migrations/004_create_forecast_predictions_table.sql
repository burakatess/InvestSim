-- Migration: Create forecast_predictions table
-- Description: AI/ML price predictions for various time horizons

CREATE TABLE IF NOT EXISTS forecast_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  horizon TEXT NOT NULL CHECK (horizon IN ('7d', '30d', '3m', '1y', '3y')),
  predicted_date DATE NOT NULL,
  predicted_price FLOAT NOT NULL,
  model_used TEXT,
  confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_forecast_asset_id ON forecast_predictions(asset_id);
CREATE INDEX IF NOT EXISTS idx_forecast_horizon ON forecast_predictions(horizon);
CREATE INDEX IF NOT EXISTS idx_forecast_predicted_date ON forecast_predictions(predicted_date);
CREATE INDEX IF NOT EXISTS idx_forecast_asset_horizon ON forecast_predictions(asset_id, horizon);

-- Add comments
COMMENT ON TABLE forecast_predictions IS 'AI/ML price predictions';
COMMENT ON COLUMN forecast_predictions.horizon IS 'Prediction timeframe: 7d, 30d, 3m, 1y, 3y';
COMMENT ON COLUMN forecast_predictions.predicted_date IS 'Target date for prediction';
COMMENT ON COLUMN forecast_predictions.model_used IS 'ML model identifier';
COMMENT ON COLUMN forecast_predictions.confidence IS 'Prediction confidence (0-1)';
