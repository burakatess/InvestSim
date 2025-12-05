/**
 * Get History Edge Function
 * Returns historical OHLCV data for an asset
 * 
 * Usage: GET /get-history?symbol=BTC&range=1m
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { UnifiedPriceEngine } from '../../../shared/services/UnifiedPriceEngine.ts';
import type { HistoryRange } from '../../../shared/types/index.ts';

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
        const url = new URL(req.url);
        const symbol = url.searchParams.get('symbol');
        const range = (url.searchParams.get('range') || '1m') as HistoryRange;

        if (!symbol) {
            return new Response(
                JSON.stringify({ error: 'Missing symbol parameter' }),
                {
                    status: 400,
                    headers: { 'Content-Type': 'application/json' },
                }
            );
        }

        const validRanges = ['1d', '7d', '1m', '3m', '6m', '1y', '3y', '5y', '10y', 'all'];
        if (!validRanges.includes(range)) {
            return new Response(
                JSON.stringify({ error: 'Invalid range parameter' }),
                {
                    status: 400,
                    headers: { 'Content-Type': 'application/json' },
                }
            );
        }

        const engine = new UnifiedPriceEngine(SUPABASE_URL, SUPABASE_SERVICE_KEY);
        const data = await engine.getHistory(symbol, range);

        return new Response(
            JSON.stringify({
                symbol,
                range,
                data,
                count: data.length,
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
        console.error('get-history error:', error);
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    }
});
