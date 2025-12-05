/**
 * Get Batch Prices Edge Function
 * Returns current prices for multiple assets
 * 
 * Usage: POST /get-batch-prices
 * Body: { "symbols": ["BTC", "ETH", "AAPL"] }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { UnifiedPriceEngine } from '../../../shared/services/UnifiedPriceEngine.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response(null, {
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
        });
    }

    try {
        const { symbols } = await req.json();

        if (!symbols || !Array.isArray(symbols) || symbols.length === 0) {
            return new Response(
                JSON.stringify({ error: 'Missing or invalid symbols array' }),
                {
                    status: 400,
                    headers: { 'Content-Type': 'application/json' },
                }
            );
        }

        const engine = new UnifiedPriceEngine(SUPABASE_URL, SUPABASE_SERVICE_KEY);
        const results = await engine.getBatchPrices(symbols);

        // Convert Map to array
        const prices = Array.from(results.entries()).map(([symbol, data]) => ({
            symbol,
            ...data,
        }));

        const cached = prices.filter(p => p.source === 'db').length;
        const fetched = prices.filter(p => p.source === 'provider').length;

        return new Response(
            JSON.stringify({
                prices,
                cached,
                fetched,
                total: prices.length,
            }),
            {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                },
            }
        );
    } catch (error) {
        console.error('get-batch-prices error:', error);
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    }
});
