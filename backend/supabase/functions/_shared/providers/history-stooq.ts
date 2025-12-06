/**
 * History Provider - Stocks & ETFs (using Stooq.com)
 * Free API, no API key required
 * Returns CSV data with OHLCV
 * SEPARATE from live price provider - only for backfill
 */

import { OHLCV } from './interface.ts';

const STOOQ_API = 'https://stooq.com/q/d/l/';

export class StooqHistoryProvider {
    name = 'stooq-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            // Stooq uses .us suffix for US stocks
            const stooqSymbol = symbol.toLowerCase() + '.us';

            // Format dates as YYYYMMDD
            const fromStr = from.toISOString().split('T')[0].replace(/-/g, '');
            const toStr = to.toISOString().split('T')[0].replace(/-/g, '');

            const url = `${STOOQ_API}?s=${stooqSymbol}&d1=${fromStr}&d2=${toStr}&i=d`;
            console.log(`Stooq: Fetching ${symbol} from ${fromStr} to ${toStr}`);

            const response = await fetch(url);

            if (!response.ok) {
                console.error(`Stooq API error: ${response.status}`);
                return results;
            }

            const csvText = await response.text();
            const lines = csvText.trim().split('\n');

            // Skip header line
            for (let i = 1; i < lines.length; i++) {
                const line = lines[i].trim();
                if (!line) continue;

                const [date, open, high, low, close, volume] = line.split(',');

                // Validate data
                if (!date || !close || isNaN(parseFloat(close))) continue;

                results.push({
                    date,
                    open: parseFloat(open),
                    high: parseFloat(high),
                    low: parseFloat(low),
                    close: parseFloat(close),
                    volume: volume ? parseFloat(volume) : undefined,
                });
            }

            console.log(`Stooq: Fetched ${results.length} history points for ${symbol}`);
        } catch (error) {
            console.error('Stooq history error:', error);
        }

        return results;
    }
}

export const stooqHistoryProvider = new StooqHistoryProvider();
