/**
 * History Provider - Stocks & ETFs
 * Uses Finnhub API for historical OHLCV data
 * SEPARATE from live price provider - only for backfill
 */

import { OHLCV } from './interface.ts';

const FINNHUB_API = 'https://finnhub.io/api/v1';
const FINNHUB_API_KEY = Deno.env.get('FINNHUB_API_KEY') || '';

export class StocksHistoryProvider {
    name = 'stocks-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        if (!FINNHUB_API_KEY) {
            console.error('FINNHUB_API_KEY is not set');
            return results;
        }

        try {
            const fromTs = Math.floor(from.getTime() / 1000);
            const toTs = Math.floor(to.getTime() / 1000);

            const url = `${FINNHUB_API}/stock/candle?symbol=${symbol}&resolution=D&from=${fromTs}&to=${toTs}&token=${FINNHUB_API_KEY}`;
            console.log(`Fetching history for ${symbol} from ${from.toISOString().split('T')[0]} to ${to.toISOString().split('T')[0]}`);

            const response = await fetch(url);

            if (!response.ok) {
                console.error(`Finnhub history API error: ${response.status}`);
                return results;
            }

            const data = await response.json();

            // Response: { c: [closes], h: [highs], l: [lows], o: [opens], t: [timestamps], v: [volumes], s: "ok" }
            if (data.s !== 'ok' || !data.t) {
                console.log(`No history data for ${symbol}: ${data.s}`);
                return results;
            }

            for (let i = 0; i < data.t.length; i++) {
                const date = new Date(data.t[i] * 1000).toISOString().split('T')[0];
                results.push({
                    date,
                    open: data.o[i],
                    high: data.h[i],
                    low: data.l[i],
                    close: data.c[i],
                    volume: data.v?.[i] || 0,
                });
            }

            console.log(`Fetched ${results.length} history points for ${symbol}`);
        } catch (error) {
            console.error('Stocks history error:', error);
        }

        return results;
    }
}

export const stocksHistoryProvider = new StocksHistoryProvider();
