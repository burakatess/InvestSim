/**
 * Get Price Edge Function
 * Returns current price for a single asset
 * 
 * Usage: GET /get-price?symbol=BTC
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { UnifiedPriceEngine } from '../../../shared/services/UnifiedPriceEngine.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
    // CORS headers
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
        const url = new URL(req.url);
        const symbol = url.searchParams.get('symbol');

        if (!symbol) {
            return new Response(
                JSON.stringify({ error: 'Missing symbol parameter' }),
                {
                    status: 400,
                    headers: { 'Content-Type': 'application/json' },
                }
            );
        }

        const engine = new UnifiedPriceEngine(SUPABASE_URL, SUPABASE_SERVICE_KEY);
        const result = await engine.getLatestPrice(symbol);

        if (!result) {
            return new Response(
                JSON.stringify({ error: 'Price not found' }),
                {
                    status: 404,
                    headers: { 'Content-Type': 'application/json' },
                }
            );
        }

        return new Response(
            JSON.stringify(result),
            {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                },
            }
        );
    } catch (error) {
        console.error('get-price error:', error);
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    }
});
