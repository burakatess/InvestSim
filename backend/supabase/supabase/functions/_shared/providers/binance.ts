/**
 * Binance Price Provider
 * Fetches crypto prices from Binance API
 */

import { PriceProvider, LatestPrice, OHLCV } from './interface.ts';

const BINANCE_API = 'https://api.binance.com/api/v3';

export class BinancePriceProvider implements PriceProvider {
    name = 'binance';

    async fetchLatest(symbols: string[]): Promise<Map<string, LatestPrice>> {
        const results = new Map<string, LatestPrice>();

        if (symbols.length === 0) return results;

        try {
            // Use 24hr ticker for batch price fetch
            const response = await fetch(`${BINANCE_API}/ticker/24hr`);

            if (!response.ok) {
                throw new Error(`Binance API error: ${response.status}`);
            }

            const tickers = await response.json();
            const symbolSet = new Set(symbols.map(s => s.toUpperCase()));

            for (const ticker of tickers) {
                if (symbolSet.has(ticker.symbol)) {
                    results.set(ticker.symbol, {
                        price: parseFloat(ticker.lastPrice),
                        change24h: parseFloat(ticker.priceChangePercent),
                        volume24h: parseFloat(ticker.volume),
                    });
                }
            }
        } catch (error) {
            console.error('Binance fetchLatest error:', error);
        }

        return results;
    }

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const startTime = from.getTime();
            const endTime = to.getTime();

            // Use daily candles (1d interval)
            const url = `${BINANCE_API}/klines?symbol=${symbol}&interval=1d&startTime=${startTime}&endTime=${endTime}&limit=1000`;
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`Binance API error: ${response.status}`);
            }

            const klines = await response.json();

            for (const kline of klines) {
                const date = new Date(kline[0]).toISOString().split('T')[0];
                results.push({
                    date,
                    open: parseFloat(kline[1]),
                    high: parseFloat(kline[2]),
                    low: parseFloat(kline[3]),
                    close: parseFloat(kline[4]),
                    volume: parseFloat(kline[5]),
                });
            }
        } catch (error) {
            console.error('Binance fetchHistory error:', error);
        }

        return results;
    }
}

export const binanceProvider = new BinancePriceProvider();
