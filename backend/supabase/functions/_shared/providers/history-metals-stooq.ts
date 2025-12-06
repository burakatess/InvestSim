/**
 * History Provider - Metals (Gold/Silver)
 * Uses GLD/SLV ETFs from Stooq.com as proxy for metal prices
 * SEPARATE from live price provider - only for backfill
 */

import { OHLCV } from './interface.ts';

const STOOQ_API = 'https://stooq.com/q/d/l/';

// Map metal symbols to ETF proxies (GLD = Gold, SLV = Silver)
const METAL_ETF_MAP: Record<string, string> = {
    'gold': 'gld.us',
    'silver': 'slv.us',
    'xauusd': 'gld.us',
    'xagusd': 'slv.us',
    'XAUUSD': 'gld.us',
    'XAGUSD': 'slv.us',
};

// Multiplier to convert ETF price to approximate spot price
// GLD ≈ 1/10 oz gold, SLV ≈ 1 oz silver
const MULTIPLIERS: Record<string, number> = {
    'gld.us': 10,
    'slv.us': 1,
};

export class MetalsStooqHistoryProvider {
    name = 'metals-stooq-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const stooqSymbol = METAL_ETF_MAP[symbol.toLowerCase()] || METAL_ETF_MAP[symbol];
            if (!stooqSymbol) {
                console.log(`No ETF mapping for metal: ${symbol}`);
                return results;
            }

            const multiplier = MULTIPLIERS[stooqSymbol] || 1;

            // Format dates as YYYYMMDD
            const fromStr = from.toISOString().split('T')[0].replace(/-/g, '');
            const toStr = to.toISOString().split('T')[0].replace(/-/g, '');

            const url = `${STOOQ_API}?s=${stooqSymbol}&d1=${fromStr}&d2=${toStr}&i=d`;
            console.log(`Stooq Metals: Fetching ${symbol} via ${stooqSymbol}`);

            const response = await fetch(url);

            if (!response.ok) {
                console.error(`Stooq API error: ${response.status}`);
                return results;
            }

            const csvText = await response.text();
            const lines = csvText.trim().split('\n');

            // Skip header
            for (let i = 1; i < lines.length; i++) {
                const line = lines[i].trim();
                if (!line) continue;

                const [date, open, high, low, close, volume] = line.split(',');
                if (!date || !close || isNaN(parseFloat(close))) continue;

                results.push({
                    date,
                    open: parseFloat(open) * multiplier,
                    high: parseFloat(high) * multiplier,
                    low: parseFloat(low) * multiplier,
                    close: parseFloat(close) * multiplier,
                    volume: volume ? parseFloat(volume) : undefined,
                });
            }

            console.log(`Stooq Metals: Fetched ${results.length} points for ${symbol}`);
        } catch (error) {
            console.error('Metals history error:', error);
        }

        return results;
    }
}

export const metalsStooqHistoryProvider = new MetalsStooqHistoryProvider();
