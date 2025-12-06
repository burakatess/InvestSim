/**
 * History Provider - FX (Forex)
 * Uses frankfurter.app API for historical rates
 * SEPARATE from live price provider
 */

import { OHLCV } from './interface.ts';

const FX_API = 'https://api.frankfurter.app';

export class FXHistoryProvider {
    name = 'fx-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            // Parse symbol to get currencies
            // Symbols like: TRY, USDTRY, EURTRY, EURUSD, etc.
            let baseCurrency = 'USD';
            let targetCurrency = symbol;

            if (symbol.startsWith('USD') && symbol.length > 3) {
                targetCurrency = symbol.substring(3);
            } else if (symbol.endsWith('USD') && symbol.length > 3) {
                baseCurrency = symbol.substring(0, symbol.length - 3);
                targetCurrency = 'USD';
            } else if (symbol.endsWith('TRY') && symbol.length > 3) {
                baseCurrency = symbol.substring(0, symbol.length - 3);
                targetCurrency = 'TRY';
            }

            const startDate = from.toISOString().split('T')[0];
            const endDate = to.toISOString().split('T')[0];

            const url = `${FX_API}/${startDate}..${endDate}?from=${baseCurrency}&to=${targetCurrency}`;
            console.log(`Fetching FX history: ${symbol} (${baseCurrency}→${targetCurrency})`);

            const response = await fetch(url);

            if (!response.ok) {
                console.error(`FX history API error: ${response.status}`);
                return results;
            }

            const data = await response.json();
            const rates = data.rates || {};

            for (const [date, dayRates] of Object.entries(rates)) {
                const rate = (dayRates as Record<string, number>)[targetCurrency];
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
            console.log(`Fetched ${results.length} FX history points for ${symbol}`);
        } catch (error) {
            console.error('FX history error:', error);
        }

        return results;
    }
}

export const fxHistoryProvider = new FXHistoryProvider();
