/**
 * Yahoo Finance Price Provider
 * Fetches stock and ETF prices from Yahoo Finance API
 */

import { PriceProvider, LatestPrice, OHLCV } from './interface.ts';

const YAHOO_API = 'https://query1.finance.yahoo.com/v7/finance';

export class YahooPriceProvider implements PriceProvider {
    name = 'yahoo';

    async fetchLatest(symbols: string[]): Promise<Map<string, LatestPrice>> {
        const results = new Map<string, LatestPrice>();

        if (symbols.length === 0) return results;

        try {
            // Yahoo supports batch queries with comma-separated symbols
            const symbolList = symbols.join(',');
            const url = `${YAHOO_API}/quote?symbols=${symbolList}`;

            const response = await fetch(url, {
                headers: {
                    'User-Agent': 'Mozilla/5.0',
                },
            });

            if (!response.ok) {
                throw new Error(`Yahoo API error: ${response.status}`);
            }

            const data = await response.json();
            const quotes = data.quoteResponse?.result || [];

            for (const quote of quotes) {
                results.set(quote.symbol, {
                    price: quote.regularMarketPrice || 0,
                    change24h: quote.regularMarketChangePercent || 0,
                    volume24h: quote.regularMarketVolume || 0,
                });
            }
        } catch (error) {
            console.error('Yahoo fetchLatest error:', error);
        }

        return results;
    }

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const period1 = Math.floor(from.getTime() / 1000);
            const period2 = Math.floor(to.getTime() / 1000);

            const url = `${YAHOO_API}/chart/${symbol}?period1=${period1}&period2=${period2}&interval=1d`;

            const response = await fetch(url, {
                headers: {
                    'User-Agent': 'Mozilla/5.0',
                },
            });

            if (!response.ok) {
                throw new Error(`Yahoo API error: ${response.status}`);
            }

            const data = await response.json();
            const chart = data.chart?.result?.[0];

            if (!chart) return results;

            const timestamps = chart.timestamp || [];
            const quotes = chart.indicators?.quote?.[0] || {};

            for (let i = 0; i < timestamps.length; i++) {
                const date = new Date(timestamps[i] * 1000).toISOString().split('T')[0];
                results.push({
                    date,
                    open: quotes.open?.[i] || 0,
                    high: quotes.high?.[i] || 0,
                    low: quotes.low?.[i] || 0,
                    close: quotes.close?.[i] || 0,
                    volume: quotes.volume?.[i] || 0,
                });
            }
        } catch (error) {
            console.error('Yahoo fetchHistory error:', error);
        }

        return results;
    }
}

export const yahooProvider = new YahooPriceProvider();
