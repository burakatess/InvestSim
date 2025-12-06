/**
 * cron-crypto-prices Edge Function
 * Scheduled: Every 30 seconds
 * Fetches crypto prices from Binance and updates prices_latest
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';
import { binanceProvider } from '../_shared/providers/binance.ts';

serve(async (req) => {
    // Handle CORS for manual testing
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    const startTime = Date.now();

    try {
        const supabase = getSupabaseClient();

        // Get all active crypto assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol')
            .eq('asset_class', 'crypto')
            .eq('provider', 'binance')
            .eq('is_active', true);

        if (assetsError || !assets) {
            console.error('Failed to load assets:', assetsError);
            return errorResponse('Failed to load assets', 500);
        }

        if (assets.length === 0) {
            return jsonResponse({ message: 'No crypto assets to update', count: 0 });
        }

        // Fetch prices from Binance
        const symbols = assets.map(a => a.provider_symbol);
        const prices = await binanceProvider.fetchLatest(symbols);

        // Prepare upsert data
        const updates: Array<{
            asset_id: string;
            price: number;
            percent_change_24h: number | null;
            updated_at: string;
            source: string;
        }> = [];

        for (const asset of assets) {
            const priceData = prices.get(asset.provider_symbol);
            if (priceData) {
                updates.push({
                    asset_id: asset.id,
                    price: priceData.price,
                    percent_change_24h: priceData.change24h ?? null,
                    updated_at: new Date().toISOString(),
                    source: 'binance',
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
        console.log(`✅ Updated ${updates.length} crypto prices in ${elapsed}ms`);

        return jsonResponse({
            success: true,
            updated: updates.length,
            total: assets.length,
            elapsed: `${elapsed}ms`,
        });

    } catch (error) {
        console.error('cron-crypto-prices error:', error);
        return errorResponse(error.message, 500);
    }
});
