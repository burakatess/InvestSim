/**
 * Provider Interface
 * All price providers must implement this interface
 */

import type { Asset, OHLCV, ProviderResponse, ProviderConfig } from '../types/index.ts';

export interface IPriceProvider {
    /**
     * Provider configuration
     */
    readonly config: ProviderConfig;

    /**
     * Fetch current price for a single asset
     */
    fetchPrice(asset: Asset): Promise<ProviderResponse<number>>;

    /**
     * Fetch current prices for multiple assets (batch)
     * Implements rate limiting and parallel processing
     */
    fetchBatchPrices(assets: Asset[]): Promise<ProviderResponse<Map<string, number>>>;

    /**
     * Fetch historical OHLCV data
     */
    fetchHistory(asset: Asset, days: number): Promise<ProviderResponse<OHLCV[]>>;

    /**
     * Check if provider can handle this asset type
     */
    canHandle(asset: Asset): boolean;

    /**
     * Get current rate limit status
     */
    getRateLimitStatus(): Promise<{
        remaining: number;
        reset: number;
    }>;
}

/**
 * Base Provider Class
 * Implements common functionality for all providers
 */
export abstract class BaseProvider implements IPriceProvider {
    abstract readonly config: ProviderConfig;

    abstract fetchPrice(asset: Asset): Promise<ProviderResponse<number>>;
    abstract fetchBatchPrices(assets: Asset[]): Promise<ProviderResponse<Map<string, number>>>;
    abstract fetchHistory(asset: Asset, days: number): Promise<ProviderResponse<OHLCV[]>>;
    abstract canHandle(asset: Asset): boolean;

    /**
     * Rate limit tracking
     */
    private requestCounts = {
        minute: 0,
        hour: 0,
        day: 0,
    };

    private lastReset = {
        minute: Date.now(),
        hour: Date.now(),
        day: Date.now(),
    };

    /**
     * Check and enforce rate limits
     */
    protected async checkRateLimit(): Promise<void> {
        const now = Date.now();

        // Reset counters if time window passed
        if (now - this.lastReset.minute >= 60 * 1000) {
            this.requestCounts.minute = 0;
            this.lastReset.minute = now;
        }
        if (now - this.lastReset.hour >= 60 * 60 * 1000) {
            this.requestCounts.hour = 0;
            this.lastReset.hour = now;
        }
        if (now - this.lastReset.day >= 24 * 60 * 60 * 1000) {
            this.requestCounts.day = 0;
            this.lastReset.day = now;
        }

        // Check limits
        if (this.requestCounts.minute >= this.config.rateLimit.requestsPerMinute) {
            const waitMs = 60 * 1000 - (now - this.lastReset.minute);
            throw new Error(`Rate limit exceeded. Wait ${Math.ceil(waitMs / 1000)}s`);
        }
        if (this.requestCounts.hour >= this.config.rateLimit.requestsPerHour) {
            throw new Error('Hourly rate limit exceeded');
        }
        if (this.requestCounts.day >= this.config.rateLimit.requestsPerDay) {
            throw new Error('Daily rate limit exceeded');
        }

        // Increment counters
        this.requestCounts.minute++;
        this.requestCounts.hour++;
        this.requestCounts.day++;
    }

    /**
     * Get rate limit status
     */
    async getRateLimitStatus() {
        const now = Date.now();
        return {
            remaining: this.config.rateLimit.requestsPerMinute - this.requestCounts.minute,
            reset: this.lastReset.minute + 60 * 1000,
        };
    }

    /**
     * Retry logic with exponential backoff
     */
    protected async retryWithBackoff<T>(
        fn: () => Promise<T>,
        retries = this.config.retryConfig.maxRetries
    ): Promise<T> {
        let lastError: Error | undefined;

        for (let i = 0; i <= retries; i++) {
            try {
                return await fn();
            } catch (error) {
                lastError = error as Error;

                if (i < retries) {
                    const backoff = Math.min(
                        this.config.retryConfig.backoffMs * Math.pow(2, i),
                        this.config.retryConfig.maxBackoffMs
                    );
                    console.log(`Retry ${i + 1}/${retries} after ${backoff}ms`);
                    await this.delay(backoff);
                }
            }
        }

        throw lastError;
    }

    /**
     * Delay helper
     */
    protected delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Chunk array into batches
     */
    protected chunkArray<T>(array: T[], size: number): T[][] {
        const chunks: T[][] = [];
        for (let i = 0; i < array.length; i += size) {
            chunks.push(array.slice(i, i + size));
        }
        return chunks;
    }
}
