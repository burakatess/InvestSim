/**
 * Unified Price Engine
 * Core service that orchestrates price fetching across all providers
 * Implements 3-layer caching strategy: Redis → DB → Provider
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { Asset, LatestPrice, OHLCV, HistoryRange } from '../types/index.ts';
import { binanceProvider } from '../providers/BinanceProvider.ts';
import { yahooProvider } from '../providers/YahooProvider.ts';
import { finnhubProvider } from '../providers/FinnhubProvider.ts';
import { alphaVantageProvider } from '../providers/AlphaVantageProvider.ts';

export class UnifiedPriceEngine {
    private supabase;
    private providers = new Map();

    constructor(supabaseUrl: string, supabaseKey: string) {
        this.supabase = createClient(supabaseUrl, supabaseKey);

        // Register providers
        this.providers.set('binance', binanceProvider);
        this.providers.set('finnhub', finnhubProvider);
        // Use Finnhub for stocks and ETFs (replacing Yahoo)
        this.providers.set('yahoo', finnhubProvider);
        this.providers.set('tiingo', finnhubProvider);
        // Use AlphaVantage for commodities (metals, oil, gas)
        this.providers.set('goldapi', alphaVantageProvider);
        this.providers.set('alphavantage', alphaVantageProvider);
    }

    /**
     * Get latest price with 3-layer cache strategy
     */
    async getLatestPrice(symbol: string): Promise<{
        price: number;
        change24h?: number;
        updatedAt: string;
        source: 'cache' | 'db' | 'provider';
    } | null> {
        try {
            // 1. Get asset info
            const { data: asset, error: assetError } = await this.supabase
                .from('assets')
                .select('*')
                .eq('code', symbol)
                .eq('is_active', true)
                .single();

            if (assetError || !asset) {
                console.error(`Asset not found: ${symbol}`);
                return null;
            }

            // 2. Check latest_prices table (L2 cache)
            const { data: cachedPrice } = await this.supabase
                .from('latest_prices')
                .select('*')
                .eq('asset_id', asset.id)
                .single();

            if (cachedPrice) {
                const age = Date.now() - new Date(cachedPrice.updated_at).getTime();
                const ttl = this.getCacheTTL(asset.type);

                // Return if cache is fresh
                if (age < ttl) {
                    return {
                        price: cachedPrice.price,
                        change24h: cachedPrice.percent_change_24h,
                        updatedAt: cachedPrice.updated_at,
                        source: 'db',
                    };
                }
            }

            // 3. Fetch from provider (L3)
            const provider = this.providers.get(asset.provider);
            if (!provider) {
                console.error(`Provider not found: ${asset.provider}`);
                return null;
            }

            const result = await provider.fetchPrice(asset);
            if (!result.success || !result.data) {
                console.error(`Provider fetch failed: ${result.error}`);
                return cachedPrice ? {
                    price: cachedPrice.price,
                    change24h: cachedPrice.percent_change_24h,
                    updatedAt: cachedPrice.updated_at,
                    source: 'db',
                } : null;
            }

            // 4. Update latest_prices table
            await this.supabase
                .from('latest_prices')
                .upsert({
                    asset_id: asset.id,
                    price: result.data,
                    provider: asset.provider,
                    updated_at: new Date().toISOString(),
                });

            return {
                price: result.data,
                updatedAt: new Date().toISOString(),
                source: 'provider',
            };
        } catch (error) {
            console.error('getLatestPrice error:', error);
            return null;
        }
    }

    /**
     * Get batch prices (optimized for multiple assets)
     * Strategy: Return cached prices immediately (even if stale) to prevent timeout
     * Fresh prices will be fetched in background or on next request
     */
    async getBatchPrices(symbols: string[]): Promise<Map<string, {
        price: number;
        change24h?: number;
        updatedAt: string;
        source: 'cache' | 'db' | 'provider' | 'stale_db';
    }>> {
        const results = new Map();

        try {
            // 1. Get all assets
            const { data: assets } = await this.supabase
                .from('assets')
                .select('*')
                .in('code', symbols)
                .eq('is_active', true);

            if (!assets || assets.length === 0) {
                return results;
            }

            // 2. Check latest_prices for all assets
            const assetIds = assets.map(a => a.id);
            const { data: cachedPrices } = await this.supabase
                .from('latest_prices')
                .select('*')
                .in('asset_id', assetIds);

            const priceMap = new Map(cachedPrices?.map(p => [p.asset_id, p]) || []);
            const now = Date.now();

            // 3. Return ALL cached prices (fresh or stale) immediately
            // This prevents timeout - user gets data fast
            const missingAssets: Asset[] = [];

            for (const asset of assets) {
                const cached = priceMap.get(asset.id);
                if (cached) {
                    const age = now - new Date(cached.updated_at).getTime();
                    const ttl = this.getCacheTTL(asset.type);
                    const isFresh = age < ttl;

                    results.set(asset.code, {
                        price: cached.price,
                        change24h: cached.percent_change_24h,
                        updatedAt: cached.updated_at,
                        source: isFresh ? 'db' : 'stale_db',
                    });
                } else {
                    missingAssets.push(asset);
                }
            }

            // 4. Only fetch from provider for assets with NO cache at all
            // Limit to max 5 to prevent timeout
            const assetsToFetch = missingAssets.slice(0, 5);

            if (assetsToFetch.length > 0) {
                // Group by provider
                const byProvider = new Map<string, Asset[]>();
                for (const asset of assetsToFetch) {
                    const group = byProvider.get(asset.provider) || [];
                    group.push(asset);
                    byProvider.set(asset.provider, group);
                }

                // Fetch from each provider (limited)
                for (const [providerName, providerAssets] of byProvider) {
                    const provider = this.providers.get(providerName);
                    if (!provider) continue;

                    try {
                        const result = await provider.fetchBatchPrices(providerAssets);
                        if (result.success && result.data) {
                            const updates = [];
                            for (const asset of providerAssets) {
                                const price = result.data.get(asset.provider_id);
                                if (price) {
                                    updates.push({
                                        asset_id: asset.id,
                                        price,
                                        provider: asset.provider,
                                        updated_at: new Date().toISOString(),
                                    });

                                    results.set(asset.code, {
                                        price,
                                        updatedAt: new Date().toISOString(),
                                        source: 'provider',
                                    });
                                }
                            }

                            // Batch upsert
                            if (updates.length > 0) {
                                await this.supabase
                                    .from('latest_prices')
                                    .upsert(updates);
                            }
                        }
                    } catch (error) {
                        console.error(`Provider ${providerName} fetch failed:`, error);
                        // Continue with other providers
                    }
                }
            }

            return results;
        } catch (error) {
            console.error('getBatchPrices error:', error);
            return results;
        }
    }

    /**
     * Get historical data with smart aggregation
     */
    async getHistory(symbol: string, range: HistoryRange): Promise<OHLCV[]> {
        try {
            const { data: asset } = await this.supabase
                .from('assets')
                .select('*')
                .eq('code', symbol)
                .eq('is_active', true)
                .single();

            if (!asset) {
                return [];
            }

            const days = this.rangeToDays(range);
            const now = new Date();
            const startDate = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

            // Determine which table(s) to query based on date range
            if (days <= 365) {
                // Use daily data
                return await this.fetchDailyHistory(asset.id, startDate, now);
            } else if (days <= 1095) {
                // Use weekly data
                return await this.fetchWeeklyHistory(asset.id, startDate, now);
            } else {
                // Use monthly data
                return await this.fetchMonthlyHistory(asset.id, startDate, now);
            }
        } catch (error) {
            console.error('getHistory error:', error);
            return [];
        }
    }

    /**
     * Helper: Fetch daily history
     */
    private async fetchDailyHistory(assetId: string, start: Date, end: Date): Promise<OHLCV[]> {
        const { data } = await this.supabase
            .from('price_history_daily')
            .select('date, open, high, low, close, volume, adj_close')
            .eq('asset_id', assetId)
            .gte('date', start.toISOString().split('T')[0])
            .lte('date', end.toISOString().split('T')[0])
            .order('date', { ascending: true });

        return data || [];
    }

    /**
     * Helper: Fetch weekly history
     */
    private async fetchWeeklyHistory(assetId: string, start: Date, end: Date): Promise<OHLCV[]> {
        const { data } = await this.supabase
            .from('price_history_weekly')
            .select('week_start as date, open, high, low, close, volume')
            .eq('asset_id', assetId)
            .gte('week_start', start.toISOString().split('T')[0])
            .lte('week_start', end.toISOString().split('T')[0])
            .order('week_start', { ascending: true });

        return data || [];
    }

    /**
     * Helper: Fetch monthly history
     */
    private async fetchMonthlyHistory(assetId: string, start: Date, end: Date): Promise<OHLCV[]> {
        const { data } = await this.supabase
            .from('price_history_monthly')
            .select('month_start as date, open, high, low, close, volume')
            .eq('asset_id', assetId)
            .gte('month_start', start.toISOString().split('T')[0])
            .lte('month_start', end.toISOString().split('T')[0])
            .order('month_start', { ascending: true });

        return data || [];
    }

    /**
     * Helper: Get cache TTL based on asset type
     */
    private getCacheTTL(assetType: string): number {
        const ttls = {
            crypto: 10 * 1000,      // 10 seconds
            stock: 60 * 1000,       // 60 seconds
            etf: 60 * 1000,         // 60 seconds
            fx: 300 * 1000,         // 5 minutes
            metal: 900 * 1000,      // 15 minutes
        };
        return ttls[assetType as keyof typeof ttls] || 60 * 1000;
    }

    /**
     * Helper: Convert range to days
     */
    private rangeToDays(range: HistoryRange): number {
        const ranges = {
            '1d': 1,
            '7d': 7,
            '1m': 30,
            '3m': 90,
            '6m': 180,
            '1y': 365,
            '3y': 1095,
            '5y': 1825,
            '10y': 3650,
            'all': 3650,
        };
        return ranges[range] || 365;
    }
}
