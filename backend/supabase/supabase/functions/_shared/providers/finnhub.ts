/**
 * Finnhub Stock/ETF Price Provider
 * Free tier: 60 API calls/minute
 * Replaces Yahoo Finance which now requires authentication
 */

import { PriceProvider, LatestPrice, OHLCV } from './interface.ts';

const FINNHUB_API = 'https://finnhub.io/api/v1';
const FINNHUB_API_KEY = Deno.env.get('FINNHUB_API_KEY') || '';

export class FinnhubPriceProvider implements PriceProvider {
    name = 'finnhub';

    async fetchLatest(symbols: string[]): Promise<Map<string, LatestPrice>> {
        const results = new Map<string, LatestPrice>();

        if (symbols.length === 0) return results;

        if (!FINNHUB_API_KEY) {
            console.error('FINNHUB_API_KEY is not set');
            return results;
        }

        // Finnhub doesn't have a batch endpoint, so we fetch each symbol
        // But we can parallelize with Promise.all
        const fetchPromises = symbols.map(async (symbol) => {
            try {
                const url = `${FINNHUB_API}/quote?symbol=${symbol}&token=${FINNHUB_API_KEY}`;
                const response = await fetch(url);

                if (!response.ok) {
                    console.error(`Finnhub API error for ${symbol}: ${response.status}`);
                    return null;
                }

                const data = await response.json();

                // Finnhub quote response: { c: current, d: change, dp: percent change, h: high, l: low, o: open, pc: previous close }
                if (data && data.c && data.c > 0) {
                    console.log(`Finnhub: ${symbol} = $${data.c}, change: ${data.dp}%`);
                    return {
                        symbol,
                        price: data.c,
                        change24h: data.dp || 0,
                    };
                }
                return null;
            } catch (error) {
                console.error(`Finnhub fetch error for ${symbol}:`, error);
                return null;
            }
        });

        const fetchResults = await Promise.all(fetchPromises);

        for (const result of fetchResults) {
            if (result) {
                results.set(result.symbol, {
                    price: result.price,
                    change24h: result.change24h,
                });
            }
        }

        console.log(`Finnhub: Fetched ${results.size}/${symbols.length} prices`);
        return results;
    }

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
            const response = await fetch(url);

            if (!response.ok) {
                console.error(`Finnhub history API error: ${response.status}`);
                return results;
            }

            const data = await response.json();

            // Response: { c: [closes], h: [highs], l: [lows], o: [opens], t: [timestamps], v: [volumes], s: "ok" }
            if (data.s !== 'ok' || !data.t) {
                console.error(`Finnhub: No history data for ${symbol}`);
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

            console.log(`Finnhub: Fetched ${results.length} history points for ${symbol}`);
        } catch (error) {
            console.error('Finnhub fetchHistory error:', error);
        }

        return results;
    }
}

export const finnhubProvider = new FinnhubPriceProvider();
