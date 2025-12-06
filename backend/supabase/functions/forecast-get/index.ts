/**
 * forecast-get Edge Function (Stub for Future ML)
 * GET /forecast-get?symbol=BTCUSDT&horizon=3m
 * Returns ML predictions for an asset
 * 
 * Horizons: 3d, 7d, 30d, 3m, 1y, 3y
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';

serve(async (req) => {
    // Handle CORS
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    try {
        const url = new URL(req.url);
        const symbol = url.searchParams.get('symbol');
        const horizon = url.searchParams.get('horizon') || '3m';

        if (!symbol) {
            return errorResponse('Missing required parameter: symbol', 400);
        }

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

        // Get predictions
        const { data, error } = await supabase
            .from('forecast_predictions')
            .select('predicted_date, predicted_price, model_name, confidence, created_at')
            .eq('asset_id', asset.id)
            .eq('horizon', horizon)
            .order('predicted_date', { ascending: true });

        if (error) {
            console.error('Database error:', error);
            return errorResponse('Database query failed', 500);
        }

        return jsonResponse({
            symbol,
            horizon,
            count: data?.length || 0,
            predictions: data || [],
            // Note: predictions will be empty until ML pipeline is implemented
            note: data?.length === 0
                ? 'No predictions available yet. ML pipeline not implemented.'
                : undefined,
        });

    } catch (error) {
        console.error('forecast-get error:', error);
        return errorResponse(error.message, 500);
    }
});
