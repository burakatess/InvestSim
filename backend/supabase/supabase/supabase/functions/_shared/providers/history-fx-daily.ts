/**
 * History Provider - FX (Daily rates)
 * Uses Twelve Data API for daily OHLCV forex data
 * Free tier: 800 credits/day, 8 credits per API call
 * SEPARATE from live price provider - only for backfill
 */

import { OHLCV } from './interface.ts';

const TWELVE_API = 'https://api.twelvedata.com';
const TWELVE_API_KEY = 'demo'; // Free demo key, limited but works

// Map our symbols to Twelve Data format
const FX_SYMBOL_MAP: Record<string, string> = {
    'USDTRY': 'USD/TRY',
    'TRY': 'USD/TRY',
    'EURUSD': 'EUR/USD',
    'GBPUSD': 'GBP/USD',
    'USDJPY': 'USD/JPY',
    'AUDUSD': 'AUD/USD',
    'EURTRY': 'EUR/TRY',
    'GBPTRY': 'GBP/TRY',
    'EURJPY': 'EUR/JPY',
    'USDCHF': 'USD/CHF',
};

export class FXDailyHistoryProvider {
    name = 'fx-daily-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const twelveSymbol = FX_SYMBOL_MAP[symbol.toUpperCase()] || FX_SYMBOL_MAP[symbol] || `USD/${symbol}`;

            // Calculate output size (max 5000)
            const days = Math.ceil((to.getTime() - from.getTime()) / (1000 * 60 * 60 * 24));
            const outputSize = Math.min(days, 5000);

            // Format start date
            const startDate = from.toISOString().split('T')[0];
            const endDate = to.toISOString().split('T')[0];

            const url = `${TWELVE_API}/time_series?symbol=${encodeURIComponent(twelveSymbol)}&interval=1day&start_date=${startDate}&end_date=${endDate}&outputsize=${outputSize}&apikey=${TWELVE_API_KEY}`;
            console.log(`FX Daily: Fetching ${symbol} (${twelveSymbol}) from ${startDate} to ${endDate}`);

            const response = await fetch(url);

            if (!response.ok) {
                console.error(`Twelve Data API error: ${response.status}`);
                return results;
            }

            const data = await response.json();

            if (data.status !== 'ok' || !data.values) {
                console.error(`FX Daily: No data for ${symbol}: ${data.message || 'unknown error'}`);
                return results;
            }

            for (const item of data.values) {
                results.push({
                    date: item.datetime,
                    open: parseFloat(item.open),
                    high: parseFloat(item.high),
                    low: parseFloat(item.low),
                    close: parseFloat(item.close),
                });
            }

            // Sort by date ascending
            results.sort((a, b) => a.date.localeCompare(b.date));

            console.log(`FX Daily: Fetched ${results.length} points for ${symbol}`);
        } catch (error) {
            console.error('FX daily history error:', error);
        }

        return results;
    }
}

export const fxDailyHistoryProvider = new FXDailyHistoryProvider();
