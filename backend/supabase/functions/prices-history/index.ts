/**
 * prices-history Edge Function
 * GET /prices-history?symbol=BTCUSDT&range=1m
 * Returns historical OHLCV data for a single asset
 * 
 * Ranges: 1m, 3m, 6m, 1y, 3y
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';

const RANGE_DAYS: Record<string, number> = {
    '1m': 30,
    '3m': 90,
    '6m': 180,
    '1y': 365,
    '3y': 1095,
};

serve(async (req) => {
    // Handle CORS
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    try {
        const url = new URL(req.url);
        const symbol = url.searchParams.get('symbol');
        const range = url.searchParams.get('range') || '1m';

        if (!symbol) {
            return errorResponse('Missing required parameter: symbol', 400);
        }

        const days = RANGE_DAYS[range] || 30;
        const fromDate = new Date();
        fromDate.setDate(fromDate.getDate() - days);
        const fromDateStr = fromDate.toISOString().split('T')[0];

        const supabase = getSupabaseClient();

        // Get asset ID
        const { data: asset, error: assetError } = await supabase
            .from('assets')
            .select('id')
            .eq('symbol', symbol)
            .single();

        if (assetError || !asset) {
            return errorResponse(`Asset not found: ${symbol}`, 404);
        }

        // Get historical data
        const { data, error } = await supabase
            .from('prices_history')
            .select('date, open, high, low, close, volume')
            .eq('asset_id', asset.id)
            .gte('date', fromDateStr)
            .order('date', { ascending: true });

        if (error) {
            console.error('Database error:', error);
            return errorResponse('Database query failed', 500);
        }

        return jsonResponse({
            symbol,
            range,
            count: data?.length || 0,
            data: data || [],
        });

    } catch (error) {
        console.error('prices-history error:', error);
        return errorResponse(error.message, 500);
    }
});
