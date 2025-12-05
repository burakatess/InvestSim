/**
 * Finnhub Provider
 * Handles stock, ETF, and forex price fetching from Finnhub API
 * Free tier: 60 API calls/minute
 */

import { BaseProvider } from './ProviderInterface.ts';
import type { Asset, OHLCV, ProviderResponse, ProviderConfig } from '../types/index.ts';

export class FinnhubProvider extends BaseProvider {
    readonly config: ProviderConfig = {
        name: 'finnhub',
        baseUrl: 'https://finnhub.io/api/v1',
        rateLimit: {
            requestsPerMinute: 55, // Conservative limit (60 is max)
            requestsPerHour: 3000,
            requestsPerDay: 72000,
        },
        timeout: 10000,
        retryConfig: {
            maxRetries: 3,
            backoffMs: 1000,
            maxBackoffMs: 10000,
        },
    };

    private apiKey: string;

    constructor() {
        super();
        // Get API key from environment variable
        this.apiKey = Deno.env.get('FINNHUB_API_KEY') || '';
        if (!this.apiKey) {
            console.warn('FINNHUB_API_KEY not set in environment variables');
        }
    }

    canHandle(asset: Asset): boolean {
        // Finnhub handles stocks, ETFs, and forex
        return (asset.type === 'stock' || asset.type === 'etf' || asset.type === 'fx') &&
            (asset.provider === 'finnhub' || asset.provider === 'yahoo' ||
                asset.provider === 'tiingo' || asset.provider === 'goldapi');
    }

    /**
     * Fetch current price for a single asset
     */
    async fetchPrice(asset: Asset): Promise<ProviderResponse<number>> {
        try {
            await this.checkRateLimit();

            const symbol = this.formatSymbol(asset);

            // Use quote endpoint for stocks/ETFs
            if (asset.type === 'stock' || asset.type === 'etf') {
                return await this.fetchStockPrice(symbol);
            }

            // Use forex endpoint for FX pairs
            if (asset.type === 'fx') {
                return await this.fetchForexPrice(asset);
            }

            throw new Error(`Unsupported asset type: ${asset.type}`);
        } catch (error) {
            console.error(`Finnhub fetchPrice error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }

    /**
     * Fetch stock/ETF price using quote endpoint
     */
    private async fetchStockPrice(symbol: string): Promise<ProviderResponse<number>> {
        const url = `${this.config.baseUrl}/quote?symbol=${symbol}&token=${this.apiKey}`;

        const response = await this.retryWithBackoff(async () => {
            const res = await fetch(url, {
                signal: AbortSignal.timeout(this.config.timeout),
            });

            if (!res.ok) {
                throw new Error(`Finnhub API error: ${res.status} ${res.statusText}`);
            }

            return res.json();
        });

        // Finnhub response: { c: currentPrice, h: high, l: low, o: open, pc: previousClose, t: timestamp }
        const price = response.c;

        if (!price || price === 0) {
            throw new Error('No price data available');
        }

        return {
            success: true,
            data: price,
        };
    }

    /**
     * Fetch forex price using forex/rates endpoint
     */
    private async fetchForexPrice(asset: Asset): Promise<ProviderResponse<number>> {
        // Extract base and quote from metadata or symbol
        const metadata = asset.metadata as { base?: string; quote?: string } | null;
        const base = metadata?.base || asset.symbol.substring(0, 3);
        const quote = metadata?.quote || 'USD';

        const url = `${this.config.baseUrl}/forex/rates?base=${base}&token=${this.apiKey}`;

        const response = await this.retryWithBackoff(async () => {
            const res = await fetch(url, {
                signal: AbortSignal.timeout(this.config.timeout),
            });

            if (!res.ok) {
                throw new Error(`Finnhub API error: ${res.status} ${res.statusText}`);
            }

            return res.json();
        });

        // Finnhub forex response: { base: "EUR", quote: { USD: 1.18, ... } }
        const rate = response.quote?.[quote];

        if (!rate || rate === 0) {
            throw new Error('No forex rate available');
        }

        return {
            success: true,
            data: rate,
        };
    }

    /**
     * Format symbol for Finnhub API
     */
    private formatSymbol(asset: Asset): string {
        // Finnhub uses standard symbols (e.g., AAPL, MSFT)
        // Remove any Yahoo-specific suffixes
        let symbol = asset.provider_id || asset.symbol;

        // Remove =X suffix from forex symbols
        symbol = symbol.replace('=X', '');

        return symbol.toUpperCase();
    }

    /**
     * Fetch batch prices (sequential with delay to respect rate limits)
     */
    async fetchBatchPrices(assets: Asset[]): Promise<ProviderResponse<Map<string, number>>> {
        const priceMap = new Map<string, number>();
        const errors: string[] = [];

        // Process sequentially to avoid rate limit
        for (const asset of assets) {
            try {
                const result = await this.fetchPrice(asset);

                if (result.success && result.data) {
                    priceMap.set(asset.code, result.data);
                } else {
                    errors.push(`${asset.symbol}: ${result.error || 'Unknown error'}`);
                }

                // Delay between requests to avoid rate limit (60 req/min = 1 req/sec)
                await this.delay(2000); // ~30 requests/minute (safe margin)
            } catch (error) {
                errors.push(`${asset.symbol}: ${(error as Error).message}`);
            }
        }

        if (errors.length > 0) {
            console.warn('Batch fetch errors:', errors);
        }

        return {
            success: priceMap.size > 0,
            data: priceMap,
            error: errors.length > 0 ? errors.join('; ') : undefined,
        };
    }

    /**
     * Fetch historical OHLCV data
     * Note: Finnhub free tier has limited historical data access
     */
    async fetchHistory(asset: Asset, days: number): Promise<ProviderResponse<OHLCV[]>> {
        try {
            await this.checkRateLimit();

            const symbol = this.formatSymbol(asset);
            const to = Math.floor(Date.now() / 1000);
            const from = to - (days * 24 * 60 * 60);

            const url = `${this.config.baseUrl}/stock/candle?symbol=${symbol}&resolution=D&from=${from}&to=${to}&token=${this.apiKey}`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Finnhub API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            // Finnhub response: { c: [], h: [], l: [], o: [], t: [], v: [], s: "ok" }
            if (response.s !== 'ok' || !response.t || response.t.length === 0) {
                throw new Error('No historical data available');
            }

            const ohlcv: OHLCV[] = response.t.map((timestamp: number, i: number) => ({
                timestamp: new Date(timestamp * 1000).toISOString(),
                open: response.o[i],
                high: response.h[i],
                low: response.l[i],
                close: response.c[i],
                volume: response.v[i],
            }));

            return {
                success: true,
                data: ohlcv,
            };
        } catch (error) {
            console.error(`Finnhub fetchHistory error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }
}

// Export singleton instance
export const finnhubProvider = new FinnhubProvider();
