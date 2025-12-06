/**
 * Supabase Client Helper
 * Shared Supabase client for all Edge Functions
 */

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export function getSupabaseClient(): SupabaseClient {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    return createClient(supabaseUrl, supabaseKey);
}

export interface Asset {
    id: string;
    symbol: string;
    display_name: string;
    asset_class: 'crypto' | 'stock' | 'etf' | 'fx' | 'metal';
    provider: 'binance' | 'yahoo' | 'fx' | 'metals';
    provider_symbol: string;
    currency: string;
    is_active: boolean;
}

export interface PriceLatest {
    asset_id: string;
    price: number;
    percent_change_24h: number | null;
    updated_at: string;
    source: string;
}

export interface PriceHistory {
    id: string;
    asset_id: string;
    date: string;
    open: number | null;
    high: number | null;
    low: number | null;
    close: number;
    volume: number | null;
}

/**
 * Standard CORS headers for all responses
 */
export const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

/**
 * Create JSON response with CORS headers
 */
export function jsonResponse(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
        status,
        headers: {
            'Content-Type': 'application/json',
            ...corsHeaders,
        },
    });
}

/**
 * Create error response
 */
export function errorResponse(message: string, status = 500): Response {
    return jsonResponse({ error: message }, status);
}

/**
 * Handle CORS preflight
 */
export function handleCors(req: Request): Response | null {
    if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders });
    }
    return null;
}
