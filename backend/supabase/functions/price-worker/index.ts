/**
 * Price Worker Edge Function
 * Background job that updates latest_prices table for all active assets
 * Called by GitHub Actions every 5 minutes
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { binanceProvider } from '../../../shared/providers/BinanceProvider.ts';
import { yahooProvider } from '../../../shared/providers/YahooProvider.ts';
import type { Asset } from '../../../shared/types/index.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Provider mapping - Yahoo for all non-crypto (batch API = scalable)
const providers = new Map([
    ['binance', binanceProvider],
    ['yahoo', yahooProvider],
    ['finnhub', yahooProvider],  // Fallback to Yahoo
    ['tiingo', yahooProvider],
    ['goldapi', yahooProvider],
]);

serve(async (req) => {
    // CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response(null, {
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
        });
    }

    // Simple auth check - require Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json' },
        });
    }

    const startTime = Date.now();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    try {
        console.log('🚀 Price Worker started');

        // 1. Get all active assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('*')
            .eq('is_active', true);

        if (assetsError || !assets) {
            throw new Error(`Failed to fetch assets: ${assetsError?.message}`);
        }

        console.log(`📊 Found ${assets.length} active assets`);

        // 2. Group assets by provider
        const byProvider = new Map<string, Asset[]>();
        for (const asset of assets) {
            const providerName = asset.provider || 'yahoo';
            const group = byProvider.get(providerName) || [];
            group.push(asset);
            byProvider.set(providerName, group);
        }

        // 3. Fetch prices from each provider
        let totalUpdated = 0;
        const errors: string[] = [];

        for (const [providerName, providerAssets] of byProvider) {
            const provider = providers.get(providerName);
            if (!provider) {
                console.warn(`⚠️ Provider not found: ${providerName}`);
                continue;
            }

            try {
                console.log(`📡 Fetching from ${providerName}: ${providerAssets.length} assets`);

                // Fetch in batches of 20 to avoid rate limits
                const batchSize = 20;
                for (let i = 0; i < providerAssets.length; i += batchSize) {
                    const batch = providerAssets.slice(i, i + batchSize);

                    try {
                        const result = await provider.fetchBatchPrices(batch);

                        if (result.success && result.data) {
                            const updates = [];

                            for (const asset of batch) {
                                const price = result.data.get(asset.provider_id || asset.code);
                                if (price && price > 0) {
                                    updates.push({
                                        asset_id: asset.id,
                                        price: price,
                                        provider: providerName,
                                        updated_at: new Date().toISOString(),
                                    });
                                }
                            }

                            if (updates.length > 0) {
                                const { error: upsertError } = await supabase
                                    .from('latest_prices')
                                    .upsert(updates, { onConflict: 'asset_id' });

                                if (upsertError) {
                                    console.error(`❌ Upsert error: ${upsertError.message}`);
                                } else {
                                    totalUpdated += updates.length;
                                    console.log(`✅ Updated ${updates.length} prices from ${providerName}`);
                                }
                            }
                        } else {
                            console.warn(`⚠️ ${providerName} batch failed: ${result.error}`);
                        }
                    } catch (batchError) {
                        console.error(`❌ ${providerName} batch error:`, batchError);
                        errors.push(`${providerName}: ${batchError.message}`);
                    }

                    // Small delay between batches to avoid rate limits
                    if (i + batchSize < providerAssets.length) {
                        await new Promise(resolve => setTimeout(resolve, 200));
                    }
                }
            } catch (providerError) {
                console.error(`❌ Provider ${providerName} failed:`, providerError);
                errors.push(`${providerName}: ${providerError.message}`);
            }
        }

        const duration = Date.now() - startTime;
        console.log(`✅ Price Worker completed: ${totalUpdated} prices updated in ${duration}ms`);

        return new Response(
            JSON.stringify({
                success: true,
                totalAssets: assets.length,
                totalUpdated,
                duration: `${duration}ms`,
                errors: errors.length > 0 ? errors : undefined,
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
        console.error('❌ Price Worker error:', error);
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    }
});
