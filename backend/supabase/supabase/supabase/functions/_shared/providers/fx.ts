/**
 * FX Price Provider
 * Fetches forex rates from frankfurter.app API (free, no API key needed)
 */

import { PriceProvider, LatestPrice, OHLCV } from './interface.ts';

// Frankfurter API - free, no API key required
const FX_API = 'https://api.frankfurter.app';

export class FXPriceProvider implements PriceProvider {
    name = 'fx';

    async fetchLatest(symbols: string[]): Promise<Map<string, LatestPrice>> {
        const results = new Map<string, LatestPrice>();

        if (symbols.length === 0) return results;

        try {
            // Get latest rates with USD as base
            const url = `${FX_API}/latest?from=USD`;

            const response = await fetch(url);

            if (!response.ok) {
                console.error(`FX API error: ${response.status}`);
                throw new Error(`FX API error: ${response.status}`);
            }

            const data = await response.json();
            const rates = data.rates || {};

            console.log(`FX API returned rates for: ${Object.keys(rates).join(', ')}`);

            // Map symbols to rates (provider_symbol contains the currency code)
            for (const symbol of symbols) {
                let rate: number | undefined;

                // Symbol is provider_symbol from DB (e.g., TRY, EUR, JPY, etc.)
                if (symbol === 'TRY' || symbol === 'USDTRY') {
                    rate = rates['TRY'];
                } else if (symbol.startsWith('USD')) {
                    const target = symbol.replace('USD', '');
                    rate = rates[target];
                } else if (symbol.endsWith('TRY')) {
                    // For EURTRY, we need EUR/TRY = USD/TRY / USD/EUR
                    const base = symbol.replace('TRY', '');
                    if (rates['TRY'] && rates[base]) {
                        rate = rates['TRY'] / rates[base];
                    }
                } else if (symbol.endsWith('USD')) {
                    // For EURUSD = 1 / USD/EUR
                    const base = symbol.replace('USD', '');
                    if (rates[base]) {
                        rate = 1 / rates[base];
                    }
                } else {
                    // Direct currency code (e.g., EUR, GBP)
                    rate = rates[symbol];
                }

                if (rate !== undefined) {
                    console.log(`FX: ${symbol} = ${rate}`);
                    results.set(symbol, {
                        price: rate,
                        change24h: 0, // FX API doesn't provide change
                    });
                }
            }
        } catch (error) {
            console.error('FX fetchLatest error:', error);
        }

        return results;
    }

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const startDate = from.toISOString().split('T')[0];
            const endDate = to.toISOString().split('T')[0];

            // exchangerate.host timeseries endpoint
            const url = `${FX_API}/timeseries?start_date=${startDate}&end_date=${endDate}&base=USD&symbols=${symbol}`;

            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`FX API error: ${response.status}`);
            }

            const data = await response.json();
            const rates = data.rates || {};

            for (const [date, dayRates] of Object.entries(rates)) {
                const rate = (dayRates as Record<string, number>)[symbol];
                if (rate !== undefined) {
                    results.push({
                        date,
                        open: rate,
                        high: rate,
                        low: rate,
                        close: rate,
                    });
                }
            }

            // Sort by date
            results.sort((a, b) => a.date.localeCompare(b.date));
        } catch (error) {
            console.error('FX fetchHistory error:', error);
        }

        return results;
    }
}

export const fxProvider = new FXPriceProvider();
