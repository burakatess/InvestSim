/**
 * Provider Interface
 * Abstract interface for all price data providers
 */

export interface LatestPrice {
    price: number;
    change24h?: number;
    volume24h?: number;
}

export interface OHLCV {
    date: string; // YYYY-MM-DD
    open: number;
    high: number;
    low: number;
    close: number;
    volume?: number;
}

export interface PriceProvider {
    name: string;

    /**
     * Fetch latest prices for multiple symbols
     * @param symbols Array of provider-specific symbols
     * @returns Map of symbol -> LatestPrice
     */
    fetchLatest(symbols: string[]): Promise<Map<string, LatestPrice>>;

    /**
     * Fetch historical OHLCV data for a single symbol
     * @param symbol Provider-specific symbol
     * @param from Start date
     * @param to End date
     * @returns Array of OHLCV data points
     */
    fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]>;
}

/**
 * Provider result wrapper for error handling
 */
export interface ProviderResult<T> {
    success: boolean;
    data?: T;
    error?: string;
}
