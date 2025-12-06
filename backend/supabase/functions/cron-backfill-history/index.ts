/**
 * cron-backfill-history Edge Function
 * Scheduled: Manual trigger or Daily at 03:00 UTC
 * Backfills 3 years of historical OHLCV data for all assets
 * 
 * Uses SEPARATE history providers that don't affect live price APIs
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';
import { cryptoHistoryProvider } from '../_shared/providers/history-crypto.ts';
import { stooqHistoryProvider } from '../_shared/providers/history-stooq.ts';
import { frankfurterHistoryProvider } from '../_shared/providers/history-fx-frankfurter.ts';
import { metalsStooqHistoryProvider } from '../_shared/providers/history-metals-stooq.ts';

// Default: 3 years of history
const DEFAULT_DAYS = 1095;

// Asset class to history provider mapping
// - Crypto: Binance (unlimited history)
// - Stocks/ETFs: Stooq.com (free, no API key)
// - FX: frankfurter.app (daily ECB rates, no API key)
// - Metals: Stooq via GLD/SLV ETF proxies
const HISTORY_PROVIDERS: Record<string, { fetchHistory: (symbol: string, from: Date, to: Date) => Promise<any[]> }> = {
    crypto: cryptoHistoryProvider,
    stock: stooqHistoryProvider,
    etf: stooqHistoryProvider,
    fx: frankfurterHistoryProvider,
    metal: metalsStooqHistoryProvider,
};

serve(async (req) => {
    // Handle CORS for manual testing
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    const startTime = Date.now();
    let totalInserted = 0;
    let totalSkipped = 0;
    let totalErrors = 0;

    try {
        const supabase = getSupabaseClient();

        // Parse request body for optional parameters
        let days = DEFAULT_DAYS;
        let assetClass: string | null = null;
        let force = false;  // Force full backfill, ignore existing data

        try {
            const body = await req.json();
            days = body.days || DEFAULT_DAYS;
            assetClass = body.asset_class || null;
            force = body.force === true;
        } catch {
            // No body, use defaults
        }

        console.log(`🚀 Starting backfill: ${days} days, asset_class: ${assetClass || 'all'}, force: ${force}`);

        // Get all active assets
        let query = supabase
            .from('assets')
            .select('id, symbol, provider_symbol, asset_class, provider')
            .eq('is_active', true);

        if (assetClass) {
            query = query.eq('asset_class', assetClass);
        }

        const { data: assets, error: assetsError } = await query;

        if (assetsError || !assets) {
            console.error('Failed to load assets:', assetsError);
            return errorResponse('Failed to load assets', 500);
        }

        console.log(`📊 Processing ${assets.length} assets...`);

        // Process each asset
        for (const asset of assets) {
            try {
                // Calculate date range
                const toDate = new Date();
                let fromDate: Date;

                if (force) {
                    // Force mode: always go back full range
                    fromDate = new Date();
                    fromDate.setDate(fromDate.getDate() - days);
                    console.log(`${asset.symbol}: FORCE mode - fetching from ${fromDate.toISOString().split('T')[0]}`);
                } else {
                    // Normal mode: check last record
                    const { data: lastRecord } = await supabase
                        .from('prices_history')
                        .select('date')
                        .eq('asset_id', asset.id)
                        .order('date', { ascending: false })
                        .limit(1)
                        .single();

                    if (lastRecord?.date) {
                        // Start from day after last record
                        fromDate = new Date(lastRecord.date);
                        fromDate.setDate(fromDate.getDate() + 1);
                        console.log(`${asset.symbol}: Continuing from ${fromDate.toISOString().split('T')[0]}`);
                    } else {
                        // No history, get full range
                        fromDate = new Date();
                        fromDate.setDate(fromDate.getDate() - days);
                        console.log(`${asset.symbol}: Starting fresh from ${fromDate.toISOString().split('T')[0]}`);
                    }
                }

                // Skip if already up to date
                if (fromDate >= toDate) {
                    totalSkipped++;
                    continue;
                }

                // Get history provider for this asset class
                const provider = HISTORY_PROVIDERS[asset.asset_class];
                if (!provider) {
                    console.warn(`No history provider for: ${asset.asset_class}`);
                    totalSkipped++;
                    continue;
                }

                // Fetch historical data
                const history = await provider.fetchHistory(asset.provider_symbol, fromDate, toDate);

                if (!history || history.length === 0) {
                    console.log(`${asset.symbol}: No history data returned`);
                    totalSkipped++;
                    continue;
                }

                // Prepare insert data in batches
                const BATCH_SIZE = 500;
                const inserts = history.map(h => ({
                    asset_id: asset.id,
                    date: h.date,
                    open: h.open,
                    high: h.high,
                    low: h.low,
                    close: h.close,
                    volume: h.volume || null,
                    provider: `history-${asset.asset_class}`,
                }));

                // Insert in batches
                for (let i = 0; i < inserts.length; i += BATCH_SIZE) {
                    const batch = inserts.slice(i, i + BATCH_SIZE);

                    const { error: insertError } = await supabase
                        .from('prices_history')
                        .upsert(batch, { onConflict: 'asset_id,date' });

                    if (insertError) {
                        console.error(`Failed to insert batch for ${asset.symbol}:`, insertError.message);
                        totalErrors++;
                    }
                }

                totalInserted += history.length;
                console.log(`✅ ${asset.symbol}: Inserted ${history.length} records`);

                // Rate limiting between assets
                await new Promise(resolve => setTimeout(resolve, 200));

            } catch (error) {
                console.error(`Error processing ${asset.symbol}:`, error);
                totalErrors++;
            }
        }

        const elapsed = Date.now() - startTime;
        console.log(`🎉 Backfill complete: ${totalInserted} inserted, ${totalSkipped} skipped, ${totalErrors} errors in ${elapsed}ms`);

        return jsonResponse({
            success: true,
            totalAssets: assets.length,
            recordsInserted: totalInserted,
            assetsSkipped: totalSkipped,
            errors: totalErrors,
            daysRequested: days,
            elapsed: `${elapsed}ms`,
        });

    } catch (error) {
        console.error('cron-backfill-history error:', error);
        return errorResponse(error.message, 500);
    }
});
