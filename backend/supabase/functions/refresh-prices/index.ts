/**
 * Refresh Prices Cron Job
 * Runs every 60 seconds to update all asset prices
 * Called by pg_cron or external scheduler
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { binanceProvider } from '../../../shared/providers/BinanceProvider.ts';
import { yahooProvider } from '../../../shared/providers/YahooProvider.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
    const startTime = Date.now();

    try {
        console.log('🔄 Starting price refresh job...');

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

        // 1. Get all active assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('*')
            .eq('is_active', true);

        if (assetsError || !assets) {
            throw new Error(`Failed to fetch assets: ${assetsError?.message}`);
        }

        console.log(`📊 Found ${assets.length} active assets`);

        // 2. Group by provider
        const byProvider = new Map();
        for (const asset of assets) {
            const group = byProvider.get(asset.provider) || [];
            group.push(asset);
            byProvider.set(asset.provider, group);
        }

        // 3. Fetch prices from each provider
        const updates = [];
        let successCount = 0;
        let errorCount = 0;

        for (const [providerName, providerAssets] of byProvider) {
            console.log(`🔄 Fetching ${providerAssets.length} prices from ${providerName}...`);

            let provider;
            if (providerName === 'binance') {
                provider = binanceProvider;
            } else if (providerName === 'yahoo') {
                provider = yahooProvider;
            } else {
                console.warn(`⚠️ Unknown provider: ${providerName}`);
                continue;
            }

            try {
                const result = await provider.fetchBatchPrices(providerAssets);

                if (result.success && result.data) {
                    for (const asset of providerAssets) {
                        const price = result.data.get(asset.provider_id);
                        if (price) {
                            updates.push({
                                asset_id: asset.id,
                                price,
                                provider: asset.provider,
                                updated_at: new Date().toISOString(),
                            });
                            successCount++;
                        } else {
                            errorCount++;
                        }
                    }
                } else {
                    console.error(`❌ ${providerName} batch fetch failed: ${result.error}`);
                    errorCount += providerAssets.length;
                }
            } catch (error) {
                console.error(`❌ ${providerName} error:`, error);
                errorCount += providerAssets.length;
            }
        }

        // 4. Batch upsert to latest_prices
        if (updates.length > 0) {
            const { error: upsertError } = await supabase
                .from('latest_prices')
                .upsert(updates);

            if (upsertError) {
                throw new Error(`Failed to upsert prices: ${upsertError.message}`);
            }

            console.log(`✅ Updated ${updates.length} prices in database`);
        }

        // 5. Record metrics
        const duration = Date.now() - startTime;
        await supabase.from('system_metrics').insert([
            {
                metric_name: 'price_refresh_duration_ms',
                metric_value: duration,
                metadata: { success: successCount, errors: errorCount },
            },
            {
                metric_name: 'price_refresh_success_count',
                metric_value: successCount,
            },
            {
                metric_name: 'price_refresh_error_count',
                metric_value: errorCount,
            },
        ]);

        const summary = {
            success: true,
            duration_ms: duration,
            total_assets: assets.length,
            updated: successCount,
            errors: errorCount,
            timestamp: new Date().toISOString(),
        };

        console.log('✅ Price refresh completed:', summary);

        return new Response(
            JSON.stringify(summary),
            {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    } catch (error) {
        console.error('❌ Price refresh failed:', error);

        return new Response(
            JSON.stringify({
                success: false,
                error: error.message,
                duration_ms: Date.now() - startTime,
            }),
            {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    }
});
