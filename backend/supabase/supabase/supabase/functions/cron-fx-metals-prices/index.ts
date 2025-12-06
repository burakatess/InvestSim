/**
 * cron-fx-metals-prices Edge Function
 * Scheduled: Every 60 seconds
 * Fetches FX rates and precious metals prices
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';
import { fxProvider } from '../_shared/providers/fx.ts';
import { metalsProvider } from '../_shared/providers/metals.ts';

serve(async (req) => {
    // Handle CORS for manual testing
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    const startTime = Date.now();

    try {
        const supabase = getSupabaseClient();

        // Get all active FX and Metal assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol, asset_class, provider')
            .in('asset_class', ['fx', 'metal'])
            .eq('is_active', true);

        if (assetsError || !assets) {
            console.error('Failed to load assets:', assetsError);
            return errorResponse('Failed to load assets', 500);
        }

        if (assets.length === 0) {
            return jsonResponse({ message: 'No FX/Metal assets to update', count: 0 });
        }

        // Split by provider
        const fxAssets = assets.filter(a => a.provider === 'fx');
        const metalAssets = assets.filter(a => a.provider === 'metals');

        const updates: Array<{
            asset_id: string;
            price: number;
            percent_change_24h: number | null;
            updated_at: string;
            source: string;
        }> = [];

        // Fetch FX prices
        if (fxAssets.length > 0) {
            const fxSymbols = fxAssets.map(a => a.provider_symbol);
            const fxPrices = await fxProvider.fetchLatest(fxSymbols);

            for (const asset of fxAssets) {
                const priceData = fxPrices.get(asset.provider_symbol);
                if (priceData) {
                    updates.push({
                        asset_id: asset.id,
                        price: priceData.price,
                        percent_change_24h: priceData.change24h ?? null,
                        updated_at: new Date().toISOString(),
                        source: 'fx',
                    });
                }
            }
        }

        // Fetch Metal prices
        if (metalAssets.length > 0) {
            const metalSymbols = metalAssets.map(a => a.provider_symbol);
            const metalPrices = await metalsProvider.fetchLatest(metalSymbols);

            for (const asset of metalAssets) {
                const priceData = metalPrices.get(asset.provider_symbol);
                if (priceData) {
                    updates.push({
                        asset_id: asset.id,
                        price: priceData.price,
                        percent_change_24h: priceData.change24h ?? null,
                        updated_at: new Date().toISOString(),
                        source: 'metals',
                    });
                }
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

            // Also write to prices_history for daily historical record
            const today = new Date().toISOString().split('T')[0];
            const historyUpdates = updates.map(u => ({
                asset_id: u.asset_id,
                date: today,
                open: u.price,
                high: u.price,
                low: u.price,
                close: u.price,
                provider: u.source + '-daily',
            }));

            const { error: historyError } = await supabase
                .from('prices_history')
                .upsert(historyUpdates, { onConflict: 'asset_id,date' });

            if (historyError) {
                console.warn('History upsert warning:', historyError.message);
            }
        }

        const elapsed = Date.now() - startTime;
        console.log(`✅ Updated ${updates.length} FX/Metal prices in ${elapsed}ms`);

        return jsonResponse({
            success: true,
            updated: updates.length,
            total: assets.length,
            fxCount: fxAssets.length,
            metalCount: metalAssets.length,
            elapsed: `${elapsed}ms`,
        });

    } catch (error) {
        console.error('cron-fx-metals-prices error:', error);
        return errorResponse(error.message, 500);
    }
});
