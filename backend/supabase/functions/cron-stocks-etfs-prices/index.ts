/**
 * cron-stocks-etfs-prices Edge Function
 * Scheduled: Every 60 seconds
 * Fetches stock and ETF prices from Finnhub (free tier: 60 req/min)
 * 
 * SCALABILITY NOTE:
 * Current: 30 assets = 30 req/min (fits Finnhub free tier)
 * Future 1000+ assets: Consider:
 * - Polygon.io (free unlimited for delayed data)
 * - Tiered updates (popular assets more frequent)
 * - Multiple API keys with rotation
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';
import { finnhubProvider } from '../_shared/providers/finnhub.ts';

serve(async (req) => {
    // Handle CORS for manual testing
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    const startTime = Date.now();

    try {
        const supabase = getSupabaseClient();

        // Get all active stock and ETF assets
        // Note: provider is still 'yahoo' in DB for backward compatibility
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol')
            .in('asset_class', ['stock', 'etf'])
            .eq('is_active', true);

        if (assetsError || !assets) {
            console.error('Failed to load assets:', assetsError);
            return errorResponse('Failed to load assets', 500);
        }

        if (assets.length === 0) {
            return jsonResponse({ message: 'No stock/ETF assets to update', count: 0 });
        }

        console.log(`Fetching prices for ${assets.length} stocks/ETFs via Finnhub...`);

        // Fetch prices from Finnhub (uses provider_symbol which should be the ticker)
        const symbols = assets.map(a => a.provider_symbol || a.symbol);
        const prices = await finnhubProvider.fetchLatest(symbols);

        // Prepare upsert data
        const updates: Array<{
            asset_id: string;
            price: number;
            percent_change_24h: number | null;
            updated_at: string;
            source: string;
        }> = [];

        for (const asset of assets) {
            const symbol = asset.provider_symbol || asset.symbol;
            const priceData = prices.get(symbol);
            if (priceData) {
                updates.push({
                    asset_id: asset.id,
                    price: priceData.price,
                    percent_change_24h: priceData.change24h ?? null,
                    updated_at: new Date().toISOString(),
                    source: 'finnhub',
                });
            }
        }

        // Batch upsert to prices_latest
        if (updates.length > 0) {
            const { error: upsertError } = await supabase
                .from('prices_latest')
                .upsert(updates, { onConflict: 'asset_id' });

            if (upsertError) {
                console.error('Upsert error:', upsertError);
                return errorResponse('Failed to update prices', 500);
            }
        }

        const elapsed = Date.now() - startTime;
        console.log(`✅ Updated ${updates.length} stock/ETF prices in ${elapsed}ms`);

        return jsonResponse({
            success: true,
            updated: updates.length,
            total: assets.length,
            elapsed: `${elapsed}ms`,
        });

    } catch (error) {
        console.error('cron-stocks-etfs-prices error:', error);
        return errorResponse(error.message, 500);
    }
});

