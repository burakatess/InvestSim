/**
 * Binance Provider
 * Handles cryptocurrency price fetching from Binance API
 * Supports WebSocket for real-time prices and REST for historical data
 */

import { BaseProvider } from './ProviderInterface.ts';
import type { Asset, OHLCV, ProviderResponse, ProviderConfig } from '../types/index.ts';

export class BinanceProvider extends BaseProvider {
    readonly config: ProviderConfig = {
        name: 'binance',
        baseUrl: 'https://api.binance.com',
        rateLimit: {
            requestsPerMinute: 1200,
            requestsPerHour: 72000,
            requestsPerDay: 1728000,
        },
        timeout: 10000,
        retryConfig: {
            maxRetries: 3,
            backoffMs: 1000,
            maxBackoffMs: 10000,
        },
    };

    /**
     * Check if this provider can handle the asset
     */
    canHandle(asset: Asset): boolean {
        return asset.type === 'crypto' && asset.provider === 'binance';
    }

    /**
     * Fetch current price for a single asset
     */
    async fetchPrice(asset: Asset): Promise<ProviderResponse<number>> {
        try {
            await this.checkRateLimit();

            const url = `${this.config.baseUrl}/api/v3/ticker/price?symbol=${asset.provider_id}`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Binance API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            return {
                success: true,
                data: parseFloat(response.price),
            };
        } catch (error) {
            console.error(`Binance fetchPrice error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }

    /**
     * Fetch batch prices (optimized for multiple assets)
     */
    async fetchBatchPrices(assets: Asset[]): Promise<ProviderResponse<Map<string, number>>> {
        try {
            await this.checkRateLimit();

            // Binance supports batch ticker request
            const url = `${this.config.baseUrl}/api/v3/ticker/price`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Binance API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            // Create a map of provider_id to price
            const priceMap = new Map<string, number>();
            const binanceSymbols = new Set(assets.map(a => a.provider_id));

            for (const ticker of response) {
                if (binanceSymbols.has(ticker.symbol)) {
                    priceMap.set(ticker.symbol, parseFloat(ticker.price));
                }
            }

            return {
                success: true,
                data: priceMap,
            };
        } catch (error) {
            console.error('Binance fetchBatchPrices error:', error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }

    /**
     * Fetch historical OHLCV data
     */
    async fetchHistory(asset: Asset, days: number): Promise<ProviderResponse<OHLCV[]>> {
        try {
            await this.checkRateLimit();

            // Binance klines endpoint
            const interval = '1d'; // Daily candles
            const limit = Math.min(days, 1000); // Binance max limit
            const url = `${this.config.baseUrl}/api/v3/klines?symbol=${asset.provider_id}&interval=${interval}&limit=${limit}`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Binance API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            // Parse Binance klines format
            const ohlcv: OHLCV[] = response.map((candle: any[]) => ({
                date: new Date(candle[0]).toISOString().split('T')[0],
                open: parseFloat(candle[1]),
                high: parseFloat(candle[2]),
                low: parseFloat(candle[3]),
                close: parseFloat(candle[4]),
                volume: parseFloat(candle[5]),
            }));

            return {
                success: true,
                data: ohlcv,
            };
        } catch (error) {
            console.error(`Binance fetchHistory error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }

    /**
     * Fetch 24h statistics (includes change percentage)
     */
    async fetch24hStats(asset: Asset): Promise<ProviderResponse<{
        price: number;
        change24h: number;
        high24h: number;
        low24h: number;
        volume24h: number;
    }>> {
        try {
            await this.checkRateLimit();

            const url = `${this.config.baseUrl}/api/v3/ticker/24hr?symbol=${asset.provider_id}`;

            const response = await this.retryWithBackoff(async () => {
                const res = await fetch(url, {
                    signal: AbortSignal.timeout(this.config.timeout),
                });

                if (!res.ok) {
                    throw new Error(`Binance API error: ${res.status} ${res.statusText}`);
                }

                return res.json();
            });

            return {
                success: true,
                data: {
                    price: parseFloat(response.lastPrice),
                    change24h: parseFloat(response.priceChangePercent),
                    high24h: parseFloat(response.highPrice),
                    low24h: parseFloat(response.lowPrice),
                    volume24h: parseFloat(response.volume),
                },
            };
        } catch (error) {
            console.error(`Binance fetch24hStats error for ${asset.symbol}:`, error);
            return {
                success: false,
                error: (error as Error).message,
            };
        }
    }
}

// Export singleton instance
export const binanceProvider = new BinanceProvider();
