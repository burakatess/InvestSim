/**
 * prices-latest Edge Function
 * GET /prices-latest?symbols=BTCUSDT,AAPL,SPY
 * Returns latest prices for all active assets or filtered by symbols
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';

serve(async (req) => {
    // Handle CORS
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    try {
        const url = new URL(req.url);
        const symbolsParam = url.searchParams.get('symbols');
        const symbols = symbolsParam ? symbolsParam.split(',').map(s => s.trim()) : null;

        const supabase = getSupabaseClient();

        // Build query: join assets with prices_latest
        let query = supabase
            .from('assets')
            .select(`
        symbol,
        display_name,
        asset_class,
        currency,
        prices_latest (
          price,
          percent_change_24h,
          updated_at
        )
      `)
            .eq('is_active', true);

        // Filter by symbols if provided
        if (symbols && symbols.length > 0) {
            query = query.in('symbol', symbols);
        }

        const { data, error } = await query;

        if (error) {
            console.error('Database error:', error);
            return errorResponse('Database query failed', 500);
        }

        // Transform response to flat structure
        const prices = (data || []).map(asset => ({
            symbol: asset.symbol,
            displayName: asset.display_name,
            class: asset.asset_class,
            currency: asset.currency,
            price: asset.prices_latest?.price ?? null,
            percentChange24h: asset.prices_latest?.percent_change_24h ?? null,
            updatedAt: asset.prices_latest?.updated_at ?? null,
        }));

        return jsonResponse({
            count: prices.length,
            prices,
        });

    } catch (error) {
        console.error('prices-latest error:', error);
        return errorResponse(error.message, 500);
    }
});
