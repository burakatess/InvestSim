/**
 * Yahoo Finance Provider
 * Handles stock, ETF price fetching from Yahoo Finance API
 * Supports both v7 and v8 Chart API
 */

import { BaseProvider } from './ProviderInterface.ts';
import type { Asset, OHLCV, ProviderResponse, ProviderConfig } from '../types/index.ts';

export class YahooProvider extends BaseProvider {
    readonly config: ProviderConfig = {
        name: 'yahoo',
        baseUrl: 'https://query1.finance.yahoo.com',
        rateLimit: {
            requestsPerMinute: 100,
            requestsPerHour: 2000,
            requestsPerDay: 48000,
        },
        timeout: 15000,
        retryConfig: {
            maxRetries: 3,
            backoffMs: 2000,
            maxBackoffMs: 15000,
        },
    };

    canHandle(asset: Asset): boolean {
        return (asset.type === 'stock' || asset.type === 'etf' || asset.type === 'fx' || asset.type === 'metal' || asset.type === 'commodity') &&
            (asset.provider === 'yahoo' || asset.provider === 'tiingo' || asset.provider === 'goldapi');
    }

    /**
     * Fetch current price using Chart API (v8)
     */
    async fetchPrice(asset: Asset): Promise<ProviderResponse<number>> {
        try {
            await this.checkRateLimit();

            const symbol = this.formatSymbol(asset);
            const url = `${this.config.baseUrl}/v8/finance/chart/${symbol}`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Yahoo API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            const result = response.chart.result[0];
            const price = result.meta.regularMarketPrice;

            if (!price) {
                throw new Error('No price data available');
            }

            return {
                success: true,
                data: price,
            };
        } catch (error) {
            console.error(`Yahoo fetchPrice error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }

    private formatSymbol(asset: Asset): string {
        // Commodities use futures symbols (already formatted like GC=F, CL=F)
        if (asset.type === 'commodity') {
            return asset.provider_id;
        }
        // FX and metals that need =X suffix
        if ((asset.type === 'fx' || asset.type === 'metal') && !asset.provider_id.endsWith('=X')) {
            return `${asset.provider_id}=X`;
        }
        return asset.provider_id;
    }

    /**
     * Fetch batch prices (sequential with delay to avoid rate limit)
     */
    /**
     * Fetch batch prices using Quote API (v7)
     * Much faster than Chart API for multiple symbols
     */
    async fetchBatchPrices(assets: Asset[]): Promise<ProviderResponse<Map<string, number>>> {
        const priceMap = new Map<string, number>();
        const errors: string[] = [];

        // Process in batches of 50 (URL length limit safety)
        const batches = this.chunkArray(assets, 50);

        for (const batch of batches) {
            try {
                // Format symbols
                const symbols = batch.map(a => this.formatSymbol(a));
                const symbolString = symbols.join(',');

                const url = `${this.config.baseUrl}/v7/finance/quote?symbols=${symbolString}`;

                const response = await this.retryWithBackoff(async () => {
                    const res = await fetch(url, {
                        signal: AbortSignal.timeout(this.config.timeout),
                    });

                    if (!res.ok) {
                        throw new Error(`Yahoo API error: ${res.status} ${res.statusText}`);
                    }

                    return res.json();
                });

                const results = response.quoteResponse?.result || [];

                // Map results back to assets
                for (const quote of results) {
                    // Find matching asset (handle =X suffix)
                    const symbol = quote.symbol;
                    const price = quote.regularMarketPrice;

                    if (price !== undefined && price !== null) {
                        // Try to find by exact match or provider_id
                        const asset = batch.find(a =>
                            this.formatSymbol(a) === symbol ||
                            a.provider_id === symbol
                        );

                        if (asset) {
                            priceMap.set(asset.provider_id, price);
                        }
                    }
                }
            } catch (error) {
                console.error('Batch fetch error:', error);
                errors.push((error as Error).message);
            }
        }

        return {
            success: priceMap.size > 0, // Success if we got *any* prices
            data: priceMap,
            ...(errors.length > 0 && { error: errors.join('; ') }),
        };
    }

    /**
     * Fetch historical OHLCV data
     */
    async fetchHistory(asset: Asset, days: number): Promise<ProviderResponse<OHLCV[]>> {
        try {
            await this.checkRateLimit();

            const endDate = Math.floor(Date.now() / 1000);
            const startDate = endDate - (days * 24 * 60 * 60);

            const symbol = this.formatSymbol(asset);
            const url = `${this.config.baseUrl}/v8/finance/chart/${symbol}?period1=${startDate}&period2=${endDate}&interval=1d`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Yahoo API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            const result = response.chart.result[0];
            const timestamps = result.timestamp;
            const quote = result.indicators.quote[0];
            const adjclose = result.indicators.adjclose?.[0]?.adjclose;

            const ohlcv: OHLCV[] = timestamps.map((ts: number, i: number) => ({
                date: new Date(ts * 1000).toISOString().split('T')[0],
                open: quote.open[i],
                high: quote.high[i],
                low: quote.low[i],
                close: quote.close[i],
                volume: quote.volume[i],
                adj_close: adjclose?.[i],
            })).filter((candle: OHLCV) =>
                candle.open !== null &&
                candle.high !== null &&
                candle.low !== null &&
                candle.close !== null
            );

            return {
                success: true,
                data: ohlcv,
            };
        } catch (error) {
            console.error(`Yahoo fetchHistory error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }

    /**
     * Fetch quote with additional metadata
     */
    async fetchQuote(asset: Asset): Promise<ProviderResponse<{
        price: number;
        change24h: number;
        high24h: number;
        low24h: number;
        volume24h: number;
        marketCap?: number;
    }>> {
        try {
            await this.checkRateLimit();

            const symbol = this.formatSymbol(asset);
            const url = `${this.config.baseUrl}/v8/finance/chart/${symbol}?range=1d&interval=1d`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Yahoo API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            const result = response.chart.result[0];
            const meta = result.meta;

            return {
                success: true,
                data: {
                    price: meta.regularMarketPrice,
                    change24h: ((meta.regularMarketPrice - meta.previousClose) / meta.previousClose) * 100,
                    high24h: meta.regularMarketDayHigh,
                    low24h: meta.regularMarketDayLow,
                    volume24h: meta.regularMarketVolume,
                    marketCap: meta.marketCap,
                },
            };
        } catch (error) {
            console.error(`Yahoo fetchQuote error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }
}

export const yahooProvider = new YahooProvider();
