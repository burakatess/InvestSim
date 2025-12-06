/**
 * cron-backfill-history Edge Function
 * Scheduled: Daily at 03:00 UTC
 * Backfills missing historical OHLCV data for all assets
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';
import { binanceProvider } from '../_shared/providers/binance.ts';
import { yahooProvider } from '../_shared/providers/yahoo.ts';
import { fxProvider } from '../_shared/providers/fx.ts';
import { metalsProvider } from '../_shared/providers/metals.ts';
import type { PriceProvider } from '../_shared/providers/interface.ts';

// Provider map
const PROVIDERS: Record<string, PriceProvider> = {
    binance: binanceProvider,
    yahoo: yahooProvider,
    fx: fxProvider,
    metals: metalsProvider,
};

serve(async (req) => {
    // Handle CORS for manual testing
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    const startTime = Date.now();
    let totalInserted = 0;
    let totalSkipped = 0;

    try {
        const supabase = getSupabaseClient();

        // Get all active assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol, provider')
            .eq('is_active', true);

        if (assetsError || !assets) {
            console.error('Failed to load assets:', assetsError);
            return errorResponse('Failed to load assets', 500);
        }

        // Process each asset
        for (const asset of assets) {
            try {
                // Get last date in history
                const { data: lastRecord } = await supabase
                    .from('prices_history')
                    .select('date')
                    .eq('asset_id', asset.id)
                    .order('date', { ascending: false })
                    .limit(1)
                    .single();

                // Calculate date range
                const toDate = new Date();
                let fromDate: Date;

                if (lastRecord?.date) {
                    // Start from day after last record
                    fromDate = new Date(lastRecord.date);
                    fromDate.setDate(fromDate.getDate() + 1);
                } else {
                    // No history, get last 365 days
                    fromDate = new Date();
                    fromDate.setDate(fromDate.getDate() - 365);
                }

                // Skip if already up to date
                if (fromDate >= toDate) {
                    totalSkipped++;
                    continue;
                }

                // Get provider
                const provider = PROVIDERS[asset.provider];
                if (!provider) {
                    console.warn(`No provider for: ${asset.provider}`);
                    totalSkipped++;
                    continue;
                }

                // Fetch historical data
                const history = await provider.fetchHistory(asset.provider_symbol, fromDate, toDate);

                if (history.length === 0) {
                    totalSkipped++;
                    continue;
                }

                // Prepare insert data
                const inserts = history.map(h => ({
                    asset_id: asset.id,
                    date: h.date,
                    open: h.open,
                    high: h.high,
                    low: h.low,
                    close: h.close,
                    volume: h.volume,
                    provider: asset.provider,
                }));

                // Upsert to prices_history
                const { error: insertError } = await supabase
                    .from('prices_history')
                    .upsert(inserts, { onConflict: 'asset_id,date' });

                if (insertError) {
                    console.error(`Failed to insert history for ${asset.symbol}:`, insertError);
                } else {
                    totalInserted += history.length;
                    console.log(`📊 Inserted ${history.length} records for ${asset.symbol}`);
                }

            } catch (error) {
                console.error(`Error processing ${asset.symbol}:`, error);
                totalSkipped++;
            }
        }

        const elapsed = Date.now() - startTime;
        console.log(`✅ Backfill complete: ${totalInserted} inserted, ${totalSkipped} skipped in ${elapsed}ms`);

        return jsonResponse({
            success: true,
            totalAssets: assets.length,
            recordsInserted: totalInserted,
            assetsSkipped: totalSkipped,
            elapsed: `${elapsed}ms`,
        });

    } catch (error) {
        console.error('cron-backfill-history error:', error);
        return errorResponse(error.message, 500);
    }
});
