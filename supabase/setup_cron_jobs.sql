-- Supabase Cron Job Setup
-- Run this in Supabase SQL Editor

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enable http extension for making HTTP requests
CREATE EXTENSION IF NOT EXISTS http;

-- 1. Update Crypto Prices - Every 1 minute
-- (pg_cron doesn't support seconds, so 1 minute is minimum)
SELECT cron.schedule(
  'update-crypto-prices',
  '* * * * *',
  $$
  SELECT
    net.http_post(
      url:='https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1/update-crypto',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"}'::jsonb,
      body:='{}'::jsonb
    ) as request_id;
  $$
);

-- 2. Update Forex Prices - Every 5 minutes
SELECT cron.schedule(
  'update-forex-prices',
  '*/5 * * * *',
  $$
  SELECT
    net.http_post(
      url:='https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1/update-forex',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"}'::jsonb,
      body:='{}'::jsonb
    ) as request_id;
  $$
);

-- 3. Update Metals Prices - Every 15 minutes
SELECT cron.schedule(
  'update-metals-prices',
  '*/15 * * * *',
  $$
  SELECT
    net.http_post(
      url:='https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1/update-metals',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"}'::jsonb,
      body:='{}'::jsonb
    ) as request_id;
  $$
);

-- 4. Update US Stocks/ETFs - Every 1 minute with batch rotation
-- 90 assets ÷ 5 per batch = 18 batches
-- Each minute updates next batch, full cycle in 18 minutes
SELECT cron.schedule(
  'update-us-stocks-prices',
  '* * * * *',
  $$
  WITH batch_tracker AS (
    SELECT COALESCE(
      (SELECT COUNT(*) FROM cron.job_run_details 
       WHERE jobname = 'update-us-stocks-prices' 
       AND status = 'succeeded'),
      0
    ) % 18 AS batch_index
  )
  SELECT
    net.http_post(
      url:='https://hplmwcjyfzjghijdqypa.supabase.co/functions/v1/update-us-stocks',
      headers:='{\"Content-Type\": \"application/json\", \"Authorization\": \"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4\"}'::jsonb,
      body:=json_build_object('batchSize', 5, 'batchIndex', (SELECT batch_index FROM batch_tracker))::jsonb
    ) as request_id;
  $$
);


-- View all scheduled jobs
SELECT * FROM cron.job;

-- View job execution history
SELECT * FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 20;

-- To unschedule a job (if needed):
-- SELECT cron.unschedule('update-crypto-prices');
-- SELECT cron.unschedule('update-forex-prices');
-- SELECT cron.unschedule('update-metals-prices');
-- SELECT cron.unschedule('update-us-stocks-prices');
