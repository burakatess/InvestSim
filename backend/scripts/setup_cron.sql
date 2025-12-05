-- ============================================================================
-- CRON JOB SETUP
-- Automatically refresh prices every minute
-- ============================================================================

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enable http extension for making HTTP requests
CREATE EXTENSION IF NOT EXISTS http;

-- Create cron job for price refresh (every minute)
SELECT cron.schedule(
    'refresh-prices-every-minute',
    '* * * * *',  -- Every minute
    $$
    SELECT
      net.http_post(
        url := concat(current_setting('app.settings.supabase_url'), '/functions/v1/refresh-prices'),
        headers := jsonb_build_object(
          'Authorization', 
          concat('Bearer ', current_setting('app.settings.service_role_key'))
        )
      );
    $$
);

-- Create cron job for daily aggregation (runs at 00:05 UTC)
SELECT cron.schedule(
    'aggregate-daily-to-weekly',
    '5 0 * * *',  -- Daily at 00:05 UTC
    $$
    DO $$
    DECLARE
      asset_record RECORD;
      last_week_start DATE;
    BEGIN
      -- Get last week's Monday
      last_week_start := date_trunc('week', CURRENT_DATE - INTERVAL '7 days')::DATE;
      
      -- Aggregate for all assets
      FOR asset_record IN SELECT id FROM assets WHERE is_active = true LOOP
        PERFORM aggregate_daily_to_weekly(asset_record.id, last_week_start);
      END LOOP;
      
      RAISE NOTICE 'Weekly aggregation completed for %', last_week_start;
    END $$;
    $$
);

-- Create cron job for monthly aggregation (runs on 1st of month at 01:00 UTC)
SELECT cron.schedule(
    'aggregate-weekly-to-monthly',
    '0 1 1 * *',  -- Monthly on 1st at 01:00 UTC
    $$
    DO $$
    DECLARE
      asset_record RECORD;
      last_month_start DATE;
    BEGIN
      -- Get first day of last month
      last_month_start := date_trunc('month', CURRENT_DATE - INTERVAL '1 month')::DATE;
      
      -- Aggregate for all assets
      FOR asset_record IN SELECT id FROM assets WHERE is_active = true LOOP
        PERFORM aggregate_weekly_to_monthly(asset_record.id, last_month_start);
      END LOOP;
      
      RAISE NOTICE 'Monthly aggregation completed for %', last_month_start;
    END $$;
    $$
);

-- Create cron job for partition creation (runs on 1st of December at 02:00 UTC)
SELECT cron.schedule(
    'create-next-year-partition',
    '0 2 1 12 *',  -- Yearly on Dec 1st at 02:00 UTC
    $$
    DO $$
    DECLARE
      next_year INTEGER;
      partition_name TEXT;
      start_date TEXT;
      end_date TEXT;
    BEGIN
      next_year := EXTRACT(YEAR FROM CURRENT_DATE) + 1;
      partition_name := 'price_history_daily_' || next_year;
      start_date := next_year || '-01-01';
      end_date := (next_year + 1) || '-01-01';
      
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF price_history_daily FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        start_date,
        end_date
      );
      
      RAISE NOTICE 'Created partition % for year %', partition_name, next_year;
    END $$;
    $$
);

-- View all scheduled jobs
SELECT 
    jobid,
    schedule,
    command,
    nodename,
    nodeport,
    database,
    username,
    active
FROM cron.job
ORDER BY jobid;

-- View recent job runs
SELECT 
    jobid,
    runid,
    job_pid,
    database,
    username,
    command,
    status,
    return_message,
    start_time,
    end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;
