/**
 * History Provider - Metals (Gold, Silver)
 * Uses GLD/SLV ETF prices from Finnhub as proxy for metal prices
 * SEPARATE from live price provider
 */

import { OHLCV } from './interface.ts';
import { stocksHistoryProvider } from './history-stocks.ts';

// Map metal symbols to ETF proxies
const METAL_ETF_MAP: Record<string, string> = {
    'gold': 'GLD',
    'silver': 'SLV',
    'xauusd': 'GLD',
    'xagusd': 'SLV',
    'XAUUSD': 'GLD',
    'XAGUSD': 'SLV',
};

// GLD price to gold price conversion (GLD = ~1/10 oz gold)
const GLD_TO_GOLD_MULTIPLIER = 10;
// SLV price to silver price conversion (SLV = ~1 oz silver)
const SLV_TO_SILVER_MULTIPLIER = 1;

export class MetalsHistoryProvider {
    name = 'metals-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const symbolLower = symbol.toLowerCase();
            const etfSymbol = METAL_ETF_MAP[symbolLower] || METAL_ETF_MAP[symbol];

            if (!etfSymbol) {
                console.log(`No ETF mapping for metal: ${symbol}`);
                return results;
            }

            console.log(`Fetching metals history: ${symbol} using ETF ${etfSymbol}`);

            // Use stocks history provider to get ETF data
            const etfHistory = await stocksHistoryProvider.fetchHistory(etfSymbol, from, to);

            // Convert ETF prices to approximate metal prices
            const multiplier = etfSymbol === 'GLD' ? GLD_TO_GOLD_MULTIPLIER : SLV_TO_SILVER_MULTIPLIER;

            for (const candle of etfHistory) {
                results.push({
                    date: candle.date,
                    open: candle.open * multiplier,
                    high: candle.high * multiplier,
                    low: candle.low * multiplier,
                    close: candle.close * multiplier,
                    volume: candle.volume,
                });
            }

            console.log(`Fetched ${results.length} metals history points for ${symbol}`);
        } catch (error) {
            console.error('Metals history error:', error);
        }

        return results;
    }
}

export const metalsHistoryProvider = new MetalsHistoryProvider();
