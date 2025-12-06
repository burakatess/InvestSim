/**
 * portfolio-value Edge Function
 * GET /portfolio-value?portfolio_id=uuid
 * Returns total portfolio value and per-asset breakdown
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseClient, handleCors, jsonResponse, errorResponse } from '../_shared/supabase.ts';

serve(async (req) => {
    // Handle CORS
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    try {
        const url = new URL(req.url);
        const portfolioId = url.searchParams.get('portfolio_id');

        if (!portfolioId) {
            return errorResponse('Missing required parameter: portfolio_id', 400);
        }

        const supabase = getSupabaseClient();

        // Get portfolio info
        const { data: portfolio, error: portfolioError } = await supabase
            .from('portfolios')
            .select('id, name, base_currency')
            .eq('id', portfolioId)
            .single();

        if (portfolioError || !portfolio) {
            return errorResponse(`Portfolio not found: ${portfolioId}`, 404);
        }

        // Get positions with asset prices
        const { data: positions, error: positionsError } = await supabase
            .from('portfolio_positions')
            .select(`
        quantity,
        avg_price,
        assets (
          symbol,
          display_name,
          class,
          prices_latest (
            price
          )
        )
      `)
            .eq('portfolio_id', portfolioId);

        if (positionsError) {
            console.error('Positions error:', positionsError);
            return errorResponse('Failed to load positions', 500);
        }

        // Calculate values
        let totalValue = 0;
        const breakdown = (positions || []).map(pos => {
            const lastPrice = pos.assets?.prices_latest?.price ?? 0;
            const positionValue = pos.quantity * lastPrice;
            totalValue += positionValue;

            return {
                symbol: pos.assets?.symbol,
                displayName: pos.assets?.display_name,
                class: pos.assets?.asset_class,
                quantity: pos.quantity,
                avgPrice: pos.avg_price,
                lastPrice,
                positionValue,
                profitLoss: positionValue - (pos.quantity * pos.avg_price),
                profitLossPercent: pos.avg_price > 0
                    ? ((lastPrice - pos.avg_price) / pos.avg_price) * 100
                    : 0,
            };
        });

        // Add weights
        const withWeights = breakdown.map(pos => ({
            ...pos,
            weight: totalValue > 0 ? (pos.positionValue / totalValue) * 100 : 0,
        }));

        return jsonResponse({
            portfolioId: portfolio.id,
            name: portfolio.name,
            baseCurrency: portfolio.base_currency,
            totalValue,
            positionCount: withWeights.length,
            positions: withWeights,
        });

    } catch (error) {
        console.error('portfolio-value error:', error);
        return errorResponse(error.message, 500);
    }
});
