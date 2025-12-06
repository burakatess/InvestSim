/**
 * History Provider - FX (Daily rates from frankfurter.app)
 * Free ECB data, no API key required, daily rates since 1999
 * SEPARATE from live price provider - only for backfill
 */

import { OHLCV } from './interface.ts';

const FRANKFURTER_API = 'https://api.frankfurter.app';

// Our FX symbols map to frankfurter format
// Our format: USDTRY means 1 USD = X TRY
const FX_PAIRS: Record<string, { base: string; target: string }> = {
    'USDTRY': { base: 'USD', target: 'TRY' },
    'EURUSD': { base: 'EUR', target: 'USD' },
    'GBPUSD': { base: 'GBP', target: 'USD' },
    'USDJPY': { base: 'USD', target: 'JPY' },
    'AUDUSD': { base: 'AUD', target: 'USD' },
    'EURTRY': { base: 'EUR', target: 'TRY' },
    'GBPTRY': { base: 'GBP', target: 'TRY' },
    'EURJPY': { base: 'EUR', target: 'JPY' },
    'USDCHF': { base: 'USD', target: 'CHF' },
    'EURCAD': { base: 'EUR', target: 'CAD' },
};

export class FrankfurterHistoryProvider {
    name = 'frankfurter-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const pair = FX_PAIRS[symbol.toUpperCase()];
            if (!pair) {
                console.log(`FX: Unknown pair ${symbol}, trying USD/${symbol}`);
                return this.fetchWithBase('USD', symbol.replace('USD', ''), from, to);
            }

            return this.fetchWithBase(pair.base, pair.target, from, to);
        } catch (error) {
            console.error('Frankfurter history error:', error);
        }

        return results;
    }

    private async fetchWithBase(base: string, target: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            const fromStr = from.toISOString().split('T')[0];
            const toStr = to.toISOString().split('T')[0];

            // frankfurter.app has a limit on date range, so we need to chunk
            // Maximum is about 2-3 years per request
            const chunkSize = 365; // days
            let currentFrom = from;
            const endDate = to;

            while (currentFrom < endDate) {
                const chunkEnd = new Date(currentFrom);
                chunkEnd.setDate(chunkEnd.getDate() + chunkSize);
                const actualEnd = chunkEnd > endDate ? endDate : chunkEnd;

                const chunkFromStr = currentFrom.toISOString().split('T')[0];
                const chunkToStr = actualEnd.toISOString().split('T')[0];

                const url = `${FRANKFURTER_API}/${chunkFromStr}..${chunkToStr}?base=${base}&symbols=${target}`;
                console.log(`FX: Fetching ${base}/${target} from ${chunkFromStr} to ${chunkToStr}`);

                const response = await fetch(url);

                if (!response.ok) {
                    console.error(`Frankfurter API error: ${response.status}`);
                    break;
                }

                const data = await response.json();

                if (!data.rates) {
                    console.log(`FX: No rates for ${base}/${target}`);
                    break;
                }

                // Parse daily rates
                for (const [date, rates] of Object.entries(data.rates)) {
                    const rateObj = rates as Record<string, number>;
                    const rate = rateObj[target];
                    if (rate) {
                        results.push({
                            date,
                            open: rate,
                            high: rate,
                            low: rate,
                            close: rate,
                        });
                    }
                }

                // Move to next chunk
                currentFrom = new Date(actualEnd);
                currentFrom.setDate(currentFrom.getDate() + 1);

                // Small delay to avoid rate limiting
                await new Promise(r => setTimeout(r, 100));
            }

            // Sort by date
            results.sort((a, b) => a.date.localeCompare(b.date));
            console.log(`FX: Fetched ${results.length} daily rates for ${base}/${target}`);
        } catch (error) {
            console.error('Frankfurter fetch error:', error);
        }

        return results;
    }
}

export const frankfurterHistoryProvider = new FrankfurterHistoryProvider();
